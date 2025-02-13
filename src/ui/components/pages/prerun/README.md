# Prerun Page Handlers

This directory contains the handlers and initialization logic for the JHEEM2 prerun projections page.

## Structure

```
src/ui/components/pages/prerun/
├── handlers/
│   ├── initialize.R        # Core setup and event handlers
│   ├── interventions.R     # Selection validation and settings
│   ├── visualization.R     # Plot/table display handlers
└── index.R                # Module exports and loading
```

## Components

### initialize.R
- Creates and configures state managers (visualization, validation)
- Sets up validation manager for selection validation
- Manages the generate button and form submission
- Coordinates between visualization and intervention handlers

### interventions.R
- Manages selection validation for:
  - Intervention aspects
  - Population groups
  - Timeframes
  - Intensities
- Uses config-driven validation rules
- Collects and formats settings for submission

### visualization.R
- Manages plot/table toggle functionality
- Updates visualization state in store
- Handles UI state for visualization controls

### index.R
- Ensures proper loading order of handlers
- Exports the main initialization function

## Configuration-Based Implementation

The prerun page now uses a flexible, configuration-driven approach:

### Selector Creation
- Selectors are created based on configuration presence
- The page supports a variable number of selectors without code changes
- Core create_intervention_content uses Filter to handle optional selectors
- Example:
  ```R
  selectors <- list(
    create_location_selector("prerun"),
    create_intervention_selector("prerun"),
    # etc.
  )
  selectors <- Filter(Negate(is.null), selectors)
  ```

### Validation
- Page requirements are pulled from config (`defaults.yaml`)
- Validation checks configuration-defined requirements
- No hardcoded validation rules
- Supports different validation requirements per deployment

### Benefits
- More maintainable code
- Flexible UI based on configuration
- Easy to customize for different deployments
- Clear separation between code and configuration

## State Management

The page uses two main types of state:
1. **Validation State**: Tracks selection validity through validation_manager
2. **Visualization State**: Manages plot/table display via vis_manager

## Usage

The page is initialized through `initialize_prerun_handlers` which sets up all necessary state managers and event handlers. All validation uses the validation boundary pattern for consistent error handling.

## Key Dependencies
- validation_manager: Manages form validation state
- vis_manager: Controls visualization display
- error boundaries: Provides validation and error handling
- config system: Provides validation rules and UI configuration