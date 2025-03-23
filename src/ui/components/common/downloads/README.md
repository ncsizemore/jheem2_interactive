# Download Management System

## Overview

The download management system in JHEEM provides real-time progress indicators for file downloads. It uses a dual approach to ensure that download progress updates appear during the actual download process, not just after completion.

## Architecture

### Components

1. **Download Manager (`download_manager.R`)**: 
   - Observes the StateStore download state
   - Manages the UI representation of downloads
   - Acts as a fallback mechanism in case direct UI messaging fails

2. **UI Messenger (`src/ui/messaging/ui_messenger.R`)**:
   - Provides direct messaging to the UI, bypassing Shiny's reactive system
   - Enables real-time progress updates even when the main R thread is blocked
   - Essential for showing download progress during file downloads

3. **Frontend Components**:
   - JavaScript handlers (`www/js/interactions/download_progress.js`)
   - CSS styling (`www/css/components/feedback/download_progress.css`)

### How It Works

The system addresses a fundamental limitation in Shiny: the main R thread is blocked during downloads, preventing reactive observers from updating the UI. Our solution:

1. **StateStore Updates**: Maintains download state in the central StateStore (consistent with app architecture)
2. **Direct UI Messaging**: Uses session$sendCustomMessage to communicate directly with the browser
3. **File Size Detection**: Determines the actual file size from HTTP headers for accurate progress calculation
4. **JavaScript Handlers**: Receives messages and updates the UI with download progress

## Implementation Details

### Download Process Flow

1. **Initialization**:
   - A download is initiated and added to StateStore
   - A unique download ID and trace ID are generated for tracking
   - The UI Messenger sends an initial "start" message to create the progress UI

2. **Download Progress**:
   - During download, the system calculates progress based on bytes downloaded
   - Progress updates are sent to both StateStore and directly to the UI
   - The UI updates in real-time even though the main thread is blocked

3. **Completion/Error**:
   - Upon completion or error, appropriate messages are sent
   - The UI updates to show completion status or error message
   - The progress indicator automatically removes itself after a delay

### Key Design Decisions

1. **Dual Update Approach**: We maintain both StateStore updates and direct UI messaging because:
   - StateStore updates maintain architecture consistency but don't appear in real-time
   - Direct UI messaging provides real-time updates but breaks from the standard architecture
   - This dual approach provides the best user experience while maintaining architectural patterns

2. **Accurate Progress Calculation**: 
   - File size is determined from HTTP Content-Length headers when available
   - This provides an accurate progress percentage throughout the download

3. **Error Handling**:
   - Comprehensive error handling for network issues
   - Visual indicators for download failures
   - Integration with the application's error boundary system

## Potential Future Improvements

1. **Async Downloads**: Move to a true asynchronous download approach if/when available
2. **Enhanced Progress Info**: Add download speed and estimated time remaining
3. **Multiple Download Management**: Better handling of concurrent downloads
4. **Framework Migration**: The StateStore pattern will facilitate future migration to other frameworks

## Usage

The download system is automatically integrated with the UnifiedCacheManager's download functions. When files are downloaded through this manager, progress indicators will appear automatically.

For direct usage:

```r
# Via StateStore
store <- get_store()
store$add_download(download_id, filename)
store$update_download_progress(download_id, percent)
store$complete_download(download_id)
store$fail_download(download_id, message)

# Via UI Messenger (for real-time updates)
ui_messenger <- session$userData$ui_messenger
ui_messenger$send_download_start(download_id, filename)
ui_messenger$send_download_progress(download_id, percent)
ui_messenger$send_download_complete(download_id)
ui_messenger$send_download_error(download_id, message)
```
