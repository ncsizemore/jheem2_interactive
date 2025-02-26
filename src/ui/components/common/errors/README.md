# JHEEM2 Error Handling System

This directory contains the core components of the JHEEM2 error handling system, which uses a dual-layer approach to ensure errors are consistently visible and properly managed across the application.

## Architecture Overview

The error handling system consists of several key components:

1. **Error Boundaries**: Self-contained components that encapsulate error detection, display, and management
2. **Direct Text Errors**: Simple text-based error display for maximum compatibility
3. **Global Error State**: Central state management for error persistence across views
4. **Utility Functions**: Standardized methods for setting and clearing errors

### Core Files

- `boundaries.R`: Defines the error boundary system, error types, and severity levels
- `handlers.R`: Contains utility functions for common error handling operations

## Error Types and Severity

The system supports multiple error types and severity levels:

```r
ERROR_TYPES <- list(
    VALIDATION = "validation",  # Form validation errors
    PLOT = "plot",              # Plot rendering errors
    DATA = "data",              # Data transformation errors
    SYSTEM = "system",          # System-level errors
    STATE = "state",            # State management errors
    SIMULATION = "simulation"   # Simulation errors
)

SEVERITY_LEVELS <- list(
    WARNING = "warning",        # Non-critical warnings
    ERROR = "error",            # Standard errors
    FATAL = "fatal"             # Fatal errors that block functionality
)
```

## Error Boundaries

The system provides several specialized boundary creators:

1. **Base Boundary**: `create_error_boundary(session, output, page_id, id, state_manager)`
   - Foundation for all error boundaries
   - Handles error state management and UI rendering

2. **Validation Boundary**: `create_validation_boundary(session, output, page_id, id, state_manager)`
   - Specialized for form validation errors
   - Includes validation rules (required, type, range, custom)
   
3. **Plot Boundary**: `create_plot_boundary(session, output, page_id, id, state_manager)`
   - Specialized for plot rendering errors
   - Has specific handlers for plot, data, and settings errors

4. **Simulation Boundary**: `create_simulation_boundary(session, output, page_id, id, state_manager)`
   - Handles simulation-specific errors
   - Used by the simulation adapter

## Dual-Layer Error Display

A critical insight about the system is that it uses **two parallel mechanisms** for error display:

1. **Error Boundary System**:
   - Structured error handling with error types and severity
   - Uses `uiOutput(ns("error_display"))` for rendering
   - Controlled by `create_error_boundary` and specialized boundaries

2. **Direct Error Display**:
   - Simple text-based error messages
   - Uses `textOutput(ns("plot_error_message"))` or `textOutput(ns("table_error_message"))`
   - Set directly with `renderText()`

For full error visibility, **both systems must be present** in components. The direct error display provides immediate visibility, while the error boundary system provides structured error handling.

## Error State Persistence

To maintain error state consistency across view changes (e.g., switching between plot and table views), the system uses a global error state managed by the application's store:

```r
# Get page error state
page_error_state <- store$get_page_error_state(id)

# Update global error state
store$update_page_error_state(
  id,
  has_error = TRUE,
  message = error_message,
  type = ERROR_TYPES$SIMULATION,
  severity = SEVERITY_LEVELS$ERROR
)

# Clear global error state
store$clear_page_error_state(id)
```

## Utility Functions

The `handlers.R` file provides utility functions for common error handling operations:

```r
# Set component error in both boundary and direct output
set_component_error(
  boundary = sim_boundary,
  output = output,
  error_id = "table_error_message",
  message = error_message,
  type = ERROR_TYPES$SIMULATION,
  severity = SEVERITY_LEVELS$ERROR,
  store = store,
  page_id = id
)

# Clear component error in both boundary and direct output
clear_component_error(
  boundary = sim_boundary,
  output = output,
  error_id = "table_error_message",
  store = store,
  page_id = id
)
```

## Implementation in Components

### Component UI Pattern

When implementing error handling in component UI, include both error display mechanisms:

```r
# Component UI
tags$div(
  # Other UI elements...
  
  # Direct error display (with unique ID per component)
  tags$div(
    class = "plot-error error",
    textOutput(ns("component_error_message"), inline = FALSE)
  ),
  
  # Error boundary display
  uiOutput(ns("error_display"))
)
```

### Component Server Pattern

In the server logic, create appropriate error boundaries:

```r
# Create specialized boundary for this component
component_boundary <- create_appropriate_boundary(
  session, output, id, "boundary_id",
  state_manager = state_manager
)

# Set up error observer
observe({
  # Get page error state to sync with global errors
  page_error_state <- store$get_page_error_state(id)
  
  # Check if there's a global error for this page
  if (page_error_state$has_error && !is.null(page_error_state$message)) {
    # Set error in local boundary
    component_boundary$set_error(
      message = page_error_state$message,
      type = page_error_state$type,
      severity = page_error_state$severity
    )
    
    # Also set direct error output
    output$component_error_message <- renderText({
      sprintf("Error: %s", page_error_state$message)
    })
  }
})
```

### Error Handling Pattern

Use structured error handling with `tryCatch`:

```r
tryCatch({
  # Code that might fail
}, error = function(e) {
  # Convert error to string
  error_message <- as.character(conditionMessage(e))
  
  # Set error using utility function
  set_component_error(
    boundary = component_boundary,
    output = output,
    error_id = "component_error_message",
    message = error_message,
    type = ERROR_TYPES$APPROPRIATE_TYPE,
    severity = SEVERITY_LEVELS$ERROR,
    store = store,
    page_id = id
  )
})
```

## CSS Considerations

The error display system relies on specific CSS selectors for visibility. The key selectors include:

```css
/* Base error hiding */
.plot-error {
  display: none; /* Hide by default */
}

/* Show when it has content */
.plot-error:not(:empty) {
  display: block !important;
}

/* Specific styling for visible errors */
.plot-error:has([id$="plot_error_message"]:not(:empty)),
.plot-error:has([id$="table_error_message"]:not(:empty)),
.table-error:has([id$="table_error_message"]:not(:empty)) {
  background-color: #f8d7da;
  border-left: 5px solid #721c24;
  color: #721c24;
  /* Additional styling */
}

/* Fallback for browsers without :has() support */
.main-panel-table .plot-error:not(:empty),
.main-panel-table .table-error:not(:empty),
.main-panel-plot .plot-error:not(:empty) {
  display: block !important;
  visibility: visible !important;
}
```

## Best Practices

1. **Always use both display mechanisms** - Implement both boundary and direct text errors
2. **Clear errors when components hide** - Ensure errors are cleared when a component becomes invisible
3. **Use proper error types** - Match error types to the actual error context
4. **Convert errors to strings** - Ensure error messages are properly converted to strings
5. **Update global state** - Keep the global error state in sync with local error boundaries
6. **Use utility functions** - Leverage the handlers.R utility functions for consistency

## Debugging Tips

The system includes optional debug observers that can be enabled to track error visibility:

```r
# Debug observer for error state visibility
last_error_state <- reactiveVal(list(has_error = FALSE, message = NULL))

observe({
  # Check error boundary state
  error_state <- if (!is.null(sim_boundary)) sim_boundary$get_state() else NULL
  error_visible <- !is.null(error_state) && error_state$has_error
  
  # Only log when error state changes
  current <- list(
    has_error = error_visible,
    message = if(error_visible) error_state$message else NULL
  )
  
  prev <- last_error_state()
  if (!identical(current, prev)) {
    # Log changes
    print(sprintf("[DEBUG][%s] Error boundary: %s", id, 
                if(error_visible) "VISIBLE" else "HIDDEN"))
    
    # Update last state
    last_error_state(current)
  }
})
```
