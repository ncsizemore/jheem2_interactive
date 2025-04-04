# JHEEM Utilities

This directory contains utility modules for the JHEEM application.

## Logging System

The `logging.R` file provides a simple remote logging system to capture all console output and send it to a Loggly account. This is especially useful for debugging applications deployed on shinyapps.io where console access is limited.

### How it Works

The logging system:
1. Captures all output from `print()`, `message()`, `warning()`, and `cat()` functions
2. Forwards this output to both the R console and to Loggly
3. Adds timestamps and log levels for better tracking
4. Creates a unique session ID to group logs from the same session

### Configuration

Logging is configured using environment variables in the `.Renviron` file:

```
# Logging configuration
ENABLE_REMOTE_LOGGING=true
LOGGLY_TOKEN=your_loggly_token_here
LOGGLY_TAGS=r,shiny,jheem
```

- `ENABLE_REMOTE_LOGGING`: Set to `true` to enable sending logs to Loggly, `false` to only log to console
- `LOGGLY_TOKEN`: Your Loggly customer token (required for remote logging)
- `LOGGLY_TAGS`: Comma-separated tags to include with logs (optional)

### Setting Up Loggly

1. Sign up for a free Loggly account at https://www.loggly.com/
2. Get your customer token from the Loggly dashboard
3. Add the token to your `.Renviron` file
4. Set `ENABLE_REMOTE_LOGGING=true`

### Disabling Logging

You can temporarily disable logging by:

1. Setting `ENABLE_REMOTE_LOGGING=false` in `.Renviron`
2. Or calling `disable_logging()` in your R code
