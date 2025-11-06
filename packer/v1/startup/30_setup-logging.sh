#!/usr/bin/env bash

# Copyright 2021-2025 The MathWorks, Inc.

PS4='+ [\d \t] '
set -x

if [[ -n ${CLOUD_LOG_NAME} ]]; then

    if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then
        INSTANCE_NAME="headnode"
    else
        INSTANCE_NAME="workernode-${LOCAL_HOSTNAME}"
    fi

    MJS_LOGBASE=/var/log/mjs
    MJS_LOGFILES=$(cat << EOF
{
                        "file_path": "${MJS_LOGBASE}/mjs-service.log",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "mjs-service-${INSTANCE_NAME}"
                    },
                    {
                        "file_path": "${MJS_LOGBASE}/command_listener.log*",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "command-listener-${INSTANCE_NAME}"
                    },
                    {
                        "file_path": "${MJS_LOGBASE}/mjsdirectory-service.log*",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "mjsdirectory-service-${INSTANCE_NAME}"
                    },
EOF
    )

    if [[ ${NODE_TYPE} == 'HEADNODE' ]]; then

        MJS_LOGFILES+=$(cat << EOF

                    {
                        "file_path": "${MJS_LOGBASE}/jobmanager_*.log*",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "jobmanager-${INSTANCE_NAME}"
                    },
                    {
                        "file_path": "${MJS_LOGBASE}/jobmanager-spf-service.log*",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "jobmanager-spf-service-${INSTANCE_NAME}"
                    }
EOF
        )

    else

        # Adding each MATLAB worker log.
        for (( i=0; i < ${WORKERS_PER_NODE}; i++ )); do
            MJS_LOGFILES+=$(cat << EOF

                    {
                        "file_path":"${MJS_LOGBASE}/worker*-log*_$((i+1))*.log*",
                        "log_group_name":"${CLOUD_LOG_NAME}",
                        "log_stream_name":"worker-$((i+1))-${INSTANCE_NAME}"
                    },
EOF
            )
        done

        MJS_LOGFILES+=$(cat << EOF

                    {
                        "file_path": "${MJS_LOGBASE}/workergroup_*.log*",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "workergroup-${INSTANCE_NAME}"
                    }
EOF
        )

    fi

    INSTANCE_ID=$(curl -fs --retry 3 http://169.254.169.254/latest/meta-data/instance-id)

    # Prepare cloudwatch config file
    cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60
    },
    "metrics": {
        "namespace": "${CLOUD_LOG_NAME}",
        "metrics_collected": {
            "cpu": {
                "measurement": ["time_active","time_idle", "time_iowait"],
                "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            },
            "disk" : {
                    "resources": [ "/dev"],
                    "measurement" : [ "free", "used" ],
                    "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            },
            "diskio" : {
                    "resources": [ "/dev" ],
                    "measurement": [ "reads", "writes" ],
                    "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            },
            "mem": {
                    "measurement": [ "free", "used" ],
                    "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            },
            "swap": {
                    "measurement": [ "free", "used" ],
                    "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            },
            "processes": {
                    "measurement": [ "running", "dead", "idle", "stopped", "sleeping" ],
                    "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            },
            "net": {
                    "measurement": [ "packets_sent", "packets_recv" ],
                    "append_dimensions": { "${INSTANCE_NAME}" : "${INSTANCE_ID}" }
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/mathworks/startup.log",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "startup-${INSTANCE_NAME}"
                    },
                    {
                        "file_path": "/var/log/syslog",
                        "log_group_name": "${CLOUD_LOG_NAME}",
                        "log_stream_name": "syslog-${INSTANCE_NAME}"
                    },
                    ${MJS_LOGFILES}
                ]
            }
        }
    }
}
EOF

    # In this command:
    #     -a fetch-config causes the agent to load the latest version of the CloudWatch agent configuration file;
    #     -m tells the agent the host is on ec2;
    #     -s starts the agent;
    #     -c points to the configuration file
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
    systemctl enable amazon-cloudwatch-agent
fi
