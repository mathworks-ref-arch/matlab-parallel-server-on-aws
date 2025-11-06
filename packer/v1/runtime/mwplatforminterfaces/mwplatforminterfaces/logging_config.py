# Copyright 2024-2025 The MathWorks, Inc.

# Sets up logging for the mwplatforminterfaces package

import logging
import sys
from logging.handlers import RotatingFileHandler

class StreamToLogger:
    """Stream object that redirects writes to the logger instance."""
    def __init__(self, logger, log_level):
        self.logger = logger
        self.log_level = log_level

    def write(self, buf):
        for line in buf.rstrip().splitlines():
            self.logger.log(self.log_level, line.rstrip())

    def flush(self):
        pass

def setup_logger(
    name="mwplatforminterfaces",
    log_file="/var/log/mathworks/mwclustermanagement.log",
    level=logging.DEBUG,
):
    """Function to setup logger for mwplatforminterfaces package."""
    logger = logging.getLogger(name)
    logger.setLevel(level)

    if not logger.handlers:  # Avoid adding handlers multiple times
        file_handler = RotatingFileHandler(log_file, maxBytes=1e6, backupCount=5)
        file_handler.setLevel(level)
        formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

        # Redirect stdout and stderr to logger
        sys.stdout = StreamToLogger(logger, logging.INFO)
        sys.stderr = StreamToLogger(logger, logging.ERROR)

    return logger
