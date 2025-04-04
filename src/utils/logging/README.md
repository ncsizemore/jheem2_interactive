# JHEEM Logging System

This module provides comprehensive logging capabilities for the JHEEM application, including:

- Local file-based logging
- Google Drive integration for remote access to logs
- Automatic cleanup of old log files
- Session-based logging with unique identifiers

## Usage

The logging system is automatically initialized at application startup in `app.R`. No additional setup is required for basic usage.

### Logging Messages

```r
# Import the logging module (if not already loaded)
source("src/utils/logging.R")

# Log messages at different levels
info("Application started successfully")
warn("Configuration value missing, using default")
error("Failed to load simulation: invalid parameters")
debug("Variable value: ", x)
```

### Checking Logging Status

```r
# Get logging statistics
stats <- get_logging_stats()
print(stats)

# Get current log file path
log_file <- get_current_log_file()
```

### Manual Operations

```r
# Force upload to Google Drive
upload_logs_to_drive()

# Shut down logging (typically not needed)
shutdown_logging()
```

## Configuration

The logging system is configured through YAML. Edit `src/ui/config/components/logging.yaml` to customize behavior.

### Google Drive Authentication

For local development, the system will use browser-based authentication. For production on shinyapps.io:

1. Create a Google Service Account with access to Google Drive
2. Download the service account credentials JSON file
3. Update the configuration in `logging.yaml`:

```yaml
google_drive:
  auth_method: "service_account"
  service_account_path: "path/to/service-account.json"
```

## Files

- `logging.R` - Main public API
- `logging/core.R` - Core file-based logging functionality
- `logging/init.R` - Initialization and context management
- `logging/google_drive.R` - Google Drive integration

## Implementation Details

- Logs are stored in the configured `log_dir` (default: "logs")
- Files are named `jheem_YYYYMMDD_HHMMSS_sessionID.log`
- Google Drive uploads happen at configurable intervals
- Old log files are automatically removed to save space
