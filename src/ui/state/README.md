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

#### State Structure
```r
simulation_state = list(
    id = character(),          # Unique simulation identifier
    mode = character(),        # "prerun" or "custom"
    settings = list(),         # Settings that created this simulation
    results = list(
        simset = NULL,         # Raw JHEEM2 simulation set
        transformed = NULL     # Transformed data for display
    ),
    timestamp = POSIXct(),     # When created/updated
    status = character()       # Status tracking
)
```

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

## Important Design Decisions

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
