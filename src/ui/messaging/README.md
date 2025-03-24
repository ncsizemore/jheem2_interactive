# UI Messaging System

## Overview

The UI Messaging system provides a direct communication channel between the server and client that bypasses Shiny's reactive system. This is essential for real-time updates when the main R thread is blocked, such as during downloads or simulation runs.

## Background

Shiny's reactive system operates on a single thread. When this thread is blocked by long-running operations (downloads, simulations, etc.), the UI cannot update until the operation completes. The UI Messenger works around this limitation by sending direct messages to the browser.

## Components

1. **UIMessenger Class (`ui_messenger.R`)**:
   - R6 class that encapsulates messaging functionality
   - Provides methods for different types of messages
   - Uses Shiny's `session$sendCustomMessage` API

2. **JavaScript Handlers**:
   - Handle messages received from the server
   - Update the UI in real-time
   - Located in `www/js/interactions/`

## Supported Message Types

The UI Messenger currently supports two categories of messages:

### Download Progress
- `send_download_start`: Initiates a download progress indicator
- `send_download_progress`: Updates download progress percentage
- `send_download_complete`: Marks a download as complete
- `send_download_error`: Indicates a download error

### Simulation Progress
- `send_simulation_start`: Initiates a simulation progress indicator
- `send_simulation_progress`: Updates simulation progress percentage
- `send_simulation_complete`: Marks a simulation as complete
- `send_simulation_error`: Indicates a simulation error

## Usage

### Initialization

The UI Messenger is initialized during app startup and stored in the session:

```r
UI_MESSENGER <- create_ui_messenger(session)
session$userData$ui_messenger <- UI_MESSENGER
```

### Sending Messages

```r
# Get the UI messenger from the session
ui_messenger <- session$userData$ui_messenger

# Send a progress update
ui_messenger$send_simulation_progress(
  id = "sim_123",
  current = 5,
  total = 10,
  percent = 50,
  description = "Running Intervention"
)
```

## Integration with State Management

The UI Messenger is part of a dual approach to UI updates:

1. **State Store Updates**: Maintains the application's architectural consistency by keeping all data in the central state store
2. **Direct UI Messaging**: Provides real-time updates when the main thread is blocked

This dual approach ensures users get timely feedback while maintaining a clean architecture.

## Future Direction

The UI Messenger is a temporary solution to address limitations in Shiny's single-threaded model. In the future, it could be replaced by:

1. **Asynchronous Processing**: Moving long-running tasks to background workers
2. **WebSocket Communication**: Using a more direct communication channel
3. **Modern Web Framework**: Adopting a framework with better support for asynchronous operations

For now, it serves as a critical component for providing real-time feedback during operations that block the main thread.
