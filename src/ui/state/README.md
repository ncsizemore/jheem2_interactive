# State Management System

## Overview
The state management system handles UI state across different panels and pages in the JHEEM2 web application. It uses a combination of Shiny's reactive system and a custom store pattern.

## Directory Contents

### store.R
Core state management implementation:
- Creates and manages the central store
- Provides state update and retrieval methods
- Maintains atomic state operations

### types.R
Type definitions and validation:
- Defines state object structures
- Provides creation functions for state objects
- Validates state object properties
- Supported types:
  - `visualization_state`: Controls display visibility and type
  - `control_state`: Manages control panel settings
  - `panel_state`: Combines visualization, control, and validation states
  - `validation_state`: Handles input validation status

### visualization.R
Visualization state manager that:
- Controls plot/table display states
- Manages visibility and loading states
- Ensures proper state update sequence
- Provides interface for state changes

### controls.R
Control panel state manager that:
- Handles control panel settings
- Manages control panel visibility
- Syncs control state with store

### validation.R
Validation state manager for:
- Input validation states
- Error message handling
- Validation state persistence

## Key Components

### Store
- Central state management via `get_store()`
- Maintains panel states for different pages (e.g., "custom", "prerun")
- Tracks download progress for file operations
- Handles state updates through atomic operations

### Visualization State Manager
Located in `visualization.R`, this manager handles:
- Display visibility ("visible"/"hidden")
- Display type ("plot"/"table")
- Plot status ("ready"/"loading")

### State Update Sequence
Critical: State updates must follow this sequence for proper reactivity:
1. Update store state first
2. Update UI inputs with full page-prefixed IDs
3. Update visual components (plots, tables, etc.)

## Input ID Conventions
- Always use full prefixed IDs: `{page_id}-{input_name}`
  - Example: `custom-visualization_state`
  - Example: `prerun-display_type`
- This matches the IDs expected by conditional panels

## Example Usage

```r
# Create manager    
vis_manager <- create_visualization_manager(session, "custom", "visualization")

# Update state (follows correct sequence internally)
vis_manager$set_display_type("plot")
vis_manager$set_visibility("visible")
```

## Common Pitfalls
- Using namespaced IDs instead of full prefixed IDs
- Updating UI inputs before store state
- Not maintaining atomic state updates

## Error State Management

The state management system also handles error state persistence across different views:

### Page Error State
- Maintains error information at the page level
- Ensures errors persist when switching between views (plot/table)
- Provides a central source of truth for error conditions

#### Error State Structure
```r
page_error_state = reactiveValues(
    has_error = logical(),       # Whether an error exists
    message = character(),       # Error message
    type = character(),          # Error type from ERROR_TYPES
    severity = character(),      # Severity from SEVERITY_LEVELS
    timestamp = POSIXct()        # When the error occurred
)
```

#### Error State API
- `update_page_error_state`: Set an error for a page
- `get_page_error_state`: Get the current error state for a page
- `clear_page_error_state`: Clear error state for a page

#### Usage Pattern
```r
# Setting an error
store$update_page_error_state(
  page_id,
  has_error = TRUE,
  message = "Error message",
  type = ERROR_TYPES$SIMULATION,
  severity = SEVERITY_LEVELS$ERROR
)

# Getting error state
page_error_state <- store$get_page_error_state(page_id)
if (page_error_state$has_error) {
  # Handle error
}

# Clearing error state
store$clear_page_error_state(page_id)
```

#### Error State Synchronization
Components should include an observer to sync with the global error state:

```r
# Error persistence observer
observe({
  # Get page error state
  page_error_state <- store$get_page_error_state(id)
  
  # Check if there's a global error for this page
  if (page_error_state$has_error && !is.null(page_error_state$message)) {
    # Set error in local component
    # ...
  }
})
```

## Simulation State Management

### Simulation State
Located in `store.R`, manages:
- Simulation storage and retrieval
- Current simulation tracking per page
- Raw and transformed data handling
- Simulation matching to prevent unnecessary runs
- Automatic cleanup of old simulations

### Simulation State Structure
```r
simulation_state = list(
    id = character(),          # Unique simulation identifier
    mode = character(),        # "prerun" or "custom"
    settings = list(),         # Settings that created this simulation
    results = list(
        simset = NULL,         # Raw JHEEM2 simulation set
        transformed = NULL     # Transformed data for display
    ),
    original_base_simset = NULL, # Original base simulation for baseline comparison
    timestamp = POSIXct(),     # When created/updated
    status = character(),      # Status tracking
    progress = list()          # Progress tracking for running simulations
)
```

### Baseline Comparison Support

The state store includes a dedicated method for accessing original base simulations for baseline comparison:

```r
get_original_base_simulation = function(page_id) {
    # Get current simulation ID
    sim_id <- self$get_current_simulation_id(page_id)
    if (is.null(sim_id)) {
        return(NULL)
    }
    
    # Get the full simulation state
    sim_state <- self$get_simulation(sim_id)
    if (is.null(sim_state)) {
        return(NULL)
    }
    
    # Get the original base simulation from the top level
    if (!is.null(sim_state$original_base_simset)) {
        return(sim_state$original_base_simset)
    }
    
    # Not found
    return(NULL)
}
```

This method provides:
- A clean API for retrieving baseline simulations
- Proper error handling for missing simulations
- Independence from the results transformation system
- Integration with the plot panel for baseline comparison

#### Page-Simulation Relationship
- Each page tracks its current simulation
- Simulation ID stored in panel state
- Prevents cross-page interference
- Maintains independent state

#### Data Access Patterns
- Plot components use raw simset
- Table components use transformed data
- Store manages transformation caching
- Avoids unnecessary retransformation

#### Simulation Matching
- Checks for simulations with matching settings before creating new ones
- Compares settings objects for equality
- Reuses existing simulations when possible
- Separate matching for prerun and custom modes
- Reduces unnecessary computation

#### Automatic Cleanup
- Removes old simulations to manage memory usage
- Configurable through `state_management.yaml`
- Preserves simulations currently in use
- Parameters:
  - `default_max_age`: Standard maximum age before cleanup
  - `cleanup_interval`: How often cleanup runs
  - `high_count_threshold`: When to use aggressive cleanup
  - `aggressive_max_age`: Maximum age during aggressive cleanup
- Prevents memory issues during extended usage

## Simulation Progress State

The simulation state structure includes a `progress` field that tracks the progress of running interventions:

```r
simulation_state = {
  id: "sim_123",
  mode: "custom",
  settings: { ... },
  results: { ... },
  timestamp: "2023-01-01",
  status: "running",
  progress: {
    current: 10,      // Current simulation index
    total: 30,        // Total number of simulations
    percentage: 33,   // Progress percentage (0-100)
    done: false,      // Whether the current simulation is complete
    last_updated: ... // Timestamp of last update
  }
}
```

### Simulation Progress Updates

Due to Shiny's reactive limitations when the main R thread is blocked, progress updates use a dual approach:

1. **State Store Updates**: All progress information is stored in the state store for architectural consistency. This allows components to use the standard state management pattern when the thread is not blocked.

2. **Direct UI Messaging**: For real-time updates when the thread is blocked, progress messages are sent directly to the browser via the UI Messenger, bypassing Shiny's reactive system.

This dual approach ensures both architectural consistency and responsive user experience. In future iterations with a more modern web framework, we may be able to consolidate to just the state store approach.

#### Progress Update API

```r
# Update progress in state store
private$store$update_simulation(sim_id, list(
    progress = create_simulation_progress(
        current = index,
        total = total,
        percentage = percent,
        done = done
    )
))

# Send direct UI update
ui_messenger$send_simulation_progress(
    id = sim_id,
    current = index,
    total = total,
    percent = percent,
    description = "Running Intervention"
)
```

#### JavaScript Progress Handler Integration

The dual approach relies on JavaScript handlers to process direct messaging updates:

```javascript
// Register custom message handler for simulation progress updates
Shiny.addCustomMessageHandler("simulation_progress_update", function(data) {
    // Process based on action type
    switch(data.action) {
        case "start":
            createOrUpdateProgressItem(data);
            break;
        case "update":
            updateProgressItem(data);
            break;
        case "complete":
            completeProgressItem(data);
            break;
        case "error":
            errorProgressItem(data);
            break;
    }
});
```

## Download Progress State Management

### Download State
Located in `store.R`, manages:
- Active download tracking and progress updates
- Completed download history
- Failed download tracking with error information
- Real-time progress display integration

#### State Structure
```r
download_progress_state = list(
    active_downloads = list(),    # Currently downloading files
    completed_downloads = list(), # Successfully completed downloads
    failed_downloads = list(),    # Failed downloads with error messages
    last_updated = POSIXct()      # When the state was last updated
)

download_entry = list(
    id = character(),             # Unique download identifier
    filename = character(),       # Name of the file being downloaded
    start_time = POSIXct(),       # When the download started
    percent = numeric(),          # Progress percentage (0-100)
    total_size = numeric(),       # Total size in bytes (if known)
    last_updated = POSIXct()      # When the entry was last updated
)
```

#### Download Progress Challenges
- The main R thread is blocked during file downloads
- This prevents reactive observers from updating the UI with progress
- Solution uses a dual approach:
  1. StateStore updates maintain architectural consistency
  2. Direct UI messaging via UIMessenger provides real-time updates

#### Download Progress API
- `add_download`: Register a new download
- `update_download_progress`: Update progress percentage
- `complete_download`: Mark a download as complete
- `fail_download`: Mark a download as failed with error info
- `get_active_downloads`: Get all active downloads
- `get_completed_downloads`: Get completed download history
- `get_failed_downloads`: Get failed downloads with error info
- `clear_completed_downloads`: Remove old completed downloads
- `clear_failed_downloads`: Remove old failed downloads

#### Usage Pattern
```r
# Adding a new download
store$add_download(download_id, filename)

# Updating progress
store$update_download_progress(download_id, percent)

# Completing a download
store$complete_download(download_id)

# Handling a failed download
store$fail_download(download_id, message, ERROR_TYPES$DOWNLOAD, SEVERITY_LEVELS$ERROR)

# Getting active downloads
active_downloads <- store$get_active_downloads()
```

#### Integration with UI Messenger
For real-time updates when the main thread is blocked:

```r
# Direct UI messaging (bypasses reactive system)
ui_messenger <- session$userData$ui_messenger
ui_messenger$send_download_progress(download_id, percent)
```

#### Auto-Cleanup
- Periodically cleans up old completed and failed downloads
- Configurable number of recent downloads to retain
- Prevents UI clutter and memory usage growth

## Important Design Decisions

### Real-Time Progress Updates for Downloads and Simulations

Both download and simulation progress systems employ a dual update approach to address a fundamental limitation in Shiny:

1. **Challenge**: The main R thread is blocked during intensive operations, preventing reactive observers from updating the UI with progress information
2. **Solution**: 
   - **StateStore Updates**: Maintain application architectural consistency
   - **Direct UI Messaging**: Bypass the reactive system for real-time UI updates
   
This approach ensures users see real-time progress updates during long-running operations while maintaining the established state management patterns used throughout the application.

The implemented pattern uses:
- `UIMessenger` to send direct updates via `session$sendCustomMessage`
- JavaScript handlers to process these messages and update the UI
- StateStore to track state for consistency with the rest of the application

This dual approach solution will be replaced with a proper asynchronous mechanism when available in future framework migrations.

### Cross-Page Button State Management

The toggle buttons for plot/table views are managed with special care to prevent unintended disabling between pages.

In particular, the `sync_buttons_to_plot` function in `button_control.R` was modified to:
- Only enable buttons when data is available for a page
- Never disable buttons for other pages that don't currently have data
- This prevents a situation where generating a plot on one page would inadvertently disable toggle buttons on other pages

Before this fix, generating projections on one page would cause toggle buttons on other pages to become disabled, creating a confusing user experience.

The fix is implemented in `button_control.R`:

```r
for (suffix in names(plot_and_table_list)) {
    # Only process pages where data exists - NEVER disable other pages
    if (!is.null(plot_and_table_list[[suffix]])) {
        set_redraw_button_enabled(input, suffix, TRUE)
        set_share_button_enabled(input, suffix, TRUE)
    } else {
        # Skip disabling buttons for pages that don't have data
        print(paste("Skipping button updates for inactive page:", suffix))
    }
}
```