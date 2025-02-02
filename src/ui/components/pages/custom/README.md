# Custom Page Handlers

This directory contains the handlers and initialization logic for the JHEEM2 custom projections page.

## Structure

```
src/ui/components/pages/custom/
├── handlers/
│   ├── initialize.R        # Core setup and event handlers
│   ├── interventions.R     # Intervention validation and settings
│   ├── visualization.R     # Plot/table display handlers
└── index.R                # Module exports and loading
```

## Components

### initialize.R
- Creates and configures state managers (visualization, validation)
- Handles subgroup count validation and panel creation
- Manages the generate button and form submission
- Coordinates between visualization and intervention handlers

### interventions.R
- Manages intervention input validation using config-based rules
- Handles enabled/disabled state for intervention fields
- Validates numeric inputs against config-defined ranges
- Collects and formats settings for submission
- Provides utilities for subgroup settings collection
- Uses validation boundaries for consistent error handling

### visualization.R
- Manages plot/table toggle functionality
- Updates visualization state in store
- Handles UI state for visualization controls

### index.R
- Ensures proper loading order of handlers
- Exports the main initialization function

## State Management

The page uses three main types of state:
1. **Validation State**: Tracks form validity through validation_manager
2. **Visualization State**: Manages plot/table display via vis_manager
3. **Input State**: Handles intervention and subgroup settings

## Usage

The page is initialized through `initialize_custom_handlers` which sets up all necessary state managers and event handlers. All validation uses the validation boundary pattern for consistent error handling.

## Key Dependencies
- validation_manager: Manages form validation state
- vis_manager: Controls visualization display
- error boundaries: Provides validation and error handling
- config system: Provides validation rules and UI configuration

## Known TODOs
1. Implement demographic group validation
   - Handle "all" vs individual selections
   - Add minimum selection requirements
2. Move configuration files to src/ui/config/pages/ 