#!/usr/bin/env bash

# Copyright 2025 The MathWorks, Inc.


# Waits for an S3 bucket to become available with configurable timeout
# Usage: 
#   wait_for_s3_bucket "my-bucket" 120
#   wait_for_s3_bucket "s3://my-bucket" 120
# Args:
#   $1: Bucket name (with or without s3:// prefix)
#   $2: Timeout in seconds (optional, defaults to 60)
wait_for_s3_bucket() {
    local bucket_path="$1"
    local timeout="${2:-60}"  # Default to 60 seconds if no timeout is provided
    local start=$(date -u +%s)

    # Extract bucket name if s3:// prefix is present
    if [[ $bucket_path == s3://* ]]; then
        bucket_path=${bucket_path#s3://}
    fi
    # Extract just the bucket name without any paths
    local bucket_name=${bucket_path%%/*}

    echo "===Waiting for S3 bucket $bucket_name to be available==="
    while ! aws s3 ls "s3://$bucket_name"; do
        sleep 1s
        if (($(date -u +%s) - start > timeout)); then
            echo "The S3 bucket $bucket_name was not available within $timeout seconds."
            exit 1
        fi
    done
}

# Checks if a specific object exists in an S3 bucket
# Usage: find_object_in_S3_bucket "my-bucket" "file.txt"
# Args:
#   $1: Bucket name
#   $2: Object name to find
find_object_in_S3_bucket() {
    local bucket_name=$1
    local obj_name=$2
    echo "Attempting to find given object in $bucket_name"
    aws s3 ls "${bucket_name}/${obj_name}"
    return $?
}

# Lists all objects in an S3 bucket
# Usage: list_S3_bucket "my-bucket"
# Args:
#   $1: Bucket name
list_S3_bucket() {
    local bucket_name=$1
    echo "Attempting to list S3 bucket: $bucket_name"
    aws s3 ls "$bucket_name"
    return $?
}

# Uploads a local file to S3 bucket with AES256 encryption
# Usage: upload_file_to_s3 "/path/to/local/file.txt" "s3://my-bucket"
# Args:
#   $1: Local file path
#   $2: S3 bucket URI
upload_file_to_s3() {
    local local_file_path=$1
    local bucket_uri=$2
    local file_name=$(basename "$local_file_path")

    echo "Uploading $local_file_path to S3 bucket: $bucket_uri"
    aws s3 cp --sse AES256 "$local_file_path" "${bucket_uri}/$file_name"
    return $?
}

# Touch a file in S3 bucket
# Usage: touch_file_in_s3 s3://my-bucket/filename"
# Args:
#   $1: S3 bucket URI
touch_file_in_s3() {
    local file_uri=$1

    echo "Touching file in S3 bucket: $file_uri"
    aws s3 cp --sse AES256 - "$file_uri"
    return $?
}


# Downloads a file from S3 bucket with AES256 encryption
# Usage: download_file_from_s3 "s3://my-bucket/file.txt" "/local/path"
# Args:
#   $1: S3 bucket URI with object path
#   $2: Local destination path
download_file_from_s3() {
    local bucket_uri=$1
    local local_destination_path=$2

    echo "Downloading from S3 bucket: $bucket_uri to $local_destination_path"
    aws s3 cp --sse AES256 "$bucket_uri" "$local_destination_path"
    return $?
}

# Deletes an object from S3 bucket
# Usage: delete_object_from_s3 "s3://my-bucket/file.txt"
#        delete_object_from_s3 "my-bucket" "file.txt"
# Args:
#   $1: Full S3 URI or bucket name
#   $2: Object key (required if bucket name provided separately)
delete_object_from_s3() {
    local bucket_uri="$1"
    local object_key="$2"
    
    if [[ -z "$object_key" ]]; then
        echo "Deleting object from S3: $bucket_uri"
        aws s3 rm "$bucket_uri"
    else
        if [[ $bucket_uri == s3://* ]]; then
            bucket_uri=${bucket_uri#s3://}
        fi
        echo "Deleting object $object_key from bucket $bucket_uri"
        aws s3 rm "s3://${bucket_uri}/${object_key}"
    fi
    return $?
}

# Searches for multiple objects in S3 bucket with different modes
# Usage:
#   OR mode:  find_multiple_objects_in_S3_bucket "my-bucket" "list-or" "file1.txt" "file2.txt"
#   AND mode: find_multiple_objects_in_S3_bucket "my-bucket" "list-and" "file1.txt" "file2.txt"
#   Pattern:  find_multiple_objects_in_S3_bucket "my-bucket" "pattern" "*.txt"
# Args:
#   $1: Bucket name
#   $2: Mode (list-or, list-and, pattern)
#   $3+: Object names or pattern
find_multiple_objects_in_S3_bucket() {
    local bucket_name="$1"
    shift
    local mode="$1"
    shift
    local objects=("$@")

    if [[ -z "$bucket_name" || -z "$mode" || ${#objects[@]} -eq 0 ]]; then
        echo "Usage: find_multiple_objects_in_S3_bucket <bucket-name> <mode> <object-names...>"
        return 1
    fi

    case "$mode" in
        list-or)
            for object_name in "${objects[@]}"; do
                if aws s3api head-object --bucket "$bucket_name" --key "$object_name" >/dev/null 2>&1; then
                    echo "$object_name"
                    return 0
                fi
            done
            echo "Error: None of the objects found in bucket '$bucket_name'."
            return 1
            ;;
        
        list-and)
            for object_name in "${objects[@]}"; do
                if ! aws s3api head-object --bucket "$bucket_name" --key "$object_name" >/dev/null 2>&1; then
                    echo "Error: Object '$object_name' not found in bucket '$bucket_name'."
                    return 1
                fi
            done
            echo "All objects found in bucket '$bucket_name'."
            ;;
        
        pattern)
            local pattern="${objects[0]}"
            local bucket_path="$bucket_name"
            local bucket_name_only
            local prefix=""

            # Extract bucket name and prefix if path is provided
            if [[ $bucket_path == s3://* ]]; then
                bucket_path=${bucket_path#s3://}
            fi
            
            bucket_name_only=${bucket_path%%/*}
            if [[ $bucket_path == */* ]]; then
                prefix=${bucket_path#*/}/
            fi

            local found_objects=()
            local all_objects
            all_objects=$(aws s3api list-objects-v2 --bucket "${bucket_name_only}" --prefix "${prefix}" --query "Contents[].Key" --output text)

            for object_name in $all_objects; do
                if [[ "$object_name" == *"$pattern"* ]]; then
                    found_objects+=("$object_name")
                fi
            done

            if [[ ${#found_objects[@]} -eq 0 ]]; then
                echo "Error: No objects found with pattern '$pattern' in bucket '$bucket_path'."
                return 1
            else
                echo "Objects found with pattern '$pattern':"
                printf "%s\n" "${found_objects[@]}"
            fi

            # Return the value of all_objects
            echo "$all_objects"
            ;;
        
        *)
            echo "Error: Invalid mode '$mode'. Use 'list-or', 'list-and', or 'pattern'."
            return 1
            ;;
    esac
}

# Processes S3 bucket path and returns standardized format
# Usage: 
#   get_bucket_name "my-bucket" "name-only"
#   get_bucket_name "s3://my-bucket/path" "full-uri"
# Args:
#   $1: Input bucket path (with or without s3:// prefix)
#   $2: Return format ("name-only" or "full-uri")
get_bucket_name() {
    local bucket_path="$1"
    local format="${2:-name-only}"  # Default to name-only if not specified
    
    # Remove s3:// prefix if present
    if [[ $bucket_path == s3://* ]]; then
        bucket_path=${bucket_path#s3://}
    fi
    
    # Extract just the bucket name without any paths
    local bucket_name=${bucket_path%%/*}
    
    case "$format" in
        name-only)
            echo "$bucket_name"
            ;;
        full-uri)
            echo "s3://$bucket_name"
            ;;
        *)
            echo "$bucket_name"  # Default to name-only for unknown format
            ;;
    esac
}

# Implements exponential backoff retry mechanism for commands
# Usage: exponential_backoff 2 30 5 aws s3 ls my-bucket
# Args:
#   $1: Initial delay in seconds
#   $2: Maximum delay in seconds
#   $3: Maximum number of retries
#   $4+: Command to execute with arguments
exponential_backoff() {
    local initialDelay=$1
    local maxDelay=$2
    local maxRetries=$3

    # Bash converts strings to zero (or zero is a bad input)
    if [[ $initialDelay -eq 0 || $maxDelay -eq 0 || $maxRetries -eq 0 ]]; then
        return 1
    fi
    local delay=$initialDelay

    # Shift arguments
    shift 3
    local attempt=1

    while (( attempt <= maxRetries )); do
        if "$@"; then
            echo "Command succeeded."
            return 0
        else
            echo "Attempt $attempt failed."
        fi
        
        if ((  attempt < maxRetries )); then
            echo "Retrying in $delay seconds..."
            sleep $delay
            
            # Increase the delay
            delay=$((delay * 2))
            
            # Cap the delay at max_delay
            if (( delay >= maxDelay )); then
                delay=$maxDelay
            fi
        fi
        
        ((attempt++))
    done
    return 1
}
