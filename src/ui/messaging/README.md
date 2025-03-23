# UI Messenger

## Overview

The UI Messenger module provides a way to send direct messages to the UI, bypassing Shiny's reactive system. This is particularly useful for scenarios where the main R thread is blocked (such as during file downloads), preventing reactive observers from updating the UI.

## Background

### The Problem

Shiny's reactive system operates on a single-threaded model:
- Reactive values are updated
- Observers detect changes and run
- UI is updated accordingly

However, this system breaks down when the main thread is blocked:
- Long-running operations (like file downloads) block the main thread
- Reactive observers cannot run until the operation completes
- UI updates are delayed until the operation finishes

This creates a poor user experience for operations like file downloads, where users see no progress until the download is complete.

### The Solution

The UI Messenger provides a direct communication channel to the UI:
- Uses `session$sendCustomMessage` to send messages directly to JavaScript handlers
- JavaScript handlers update the UI immediately, even when R is busy
- Maintains the user experience during long-running operations

## Implementation

The UIMessenger is an R6 class with methods for different message types:

### Methods

- `send_download_start`: Signal the start of a download
- `send_download_progress`: Update progress during a download
- `send_download_complete`: Signal download completion
- `send_download_error`: Report download errors

### Usage

```r
# Initialize the messenger
ui_messenger <- create_ui_messenger(session)

# Make available to components
session$userData$ui_messenger <- ui_messenger

# Use in download operations
ui_messenger$send_download_start("download-123", "example.csv")
ui_messenger$send_download_progress("download-123", 50)
ui_messenger$send_download_complete("download-123")
```

## Integration

The UI Messenger is primarily used in the download process:

1. UnifiedCacheManager uses it during file downloads
2. Messages are sent in parallel with StateStore updates
3. JavaScript handlers in `download_progress.js` process these messages

## Design Considerations

### Separation of Concerns

The UI Messenger represents a temporary deviation from the standard Shiny patterns:
- StateStore remains the source of truth for application state
- UI Messenger provides a direct UI update channel when the reactive system is blocked
- Long-term, this would be replaced by true asynchronous operations

### Error Handling

The UI Messenger includes robust error handling:
- All methods use tryCatch to prevent errors from propagating
- All methods return success/failure status
- Error details are logged for troubleshooting

## Future Enhancements

In future iterations or framework migrations:
- Replace with true asynchronous download operations
- Expand to handle other long-running operations
- Consider WebSockets or Server-Sent Events for more robust messaging