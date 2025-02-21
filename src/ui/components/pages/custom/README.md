# Custom Page Handlers

This directory contains the handlers and initialization logic for the JHEEM2 custom projections page. Supports both fixed groups (ryan-white) and user-defined groups (main) through configuration-driven components.

## Structure

```
src/ui/components/pages/custom/
├── handlers/
│   ├── initialize.R        # Core setup, event handlers, config-driven group handling
│   ├── interventions.R     # Intervention validation and settings
│   ├── visualization.R     # Plot/table display handlers
└── index.R                # Module exports and loading
```

## Components

### initialize.R
- Creates and configures state managers (visualization, validation)
- Handles config-driven demographic collection
- Manages group ID generation with abbreviations
- Handles both fixed and user-defined group creation
- Supports different component types and input values
- Coordinates between visualization and intervention handlers

### interventions.R
- Manages intervention input validation using config-based rules
- Handles enabled/disabled state for intervention fields
- Validates numeric and select inputs against config-defined rules
- Collects and formats settings for submission
- Handles both compound and simple components
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
3. **Input State**: Handles intervention and demographics through config-driven structures

## Usage

The page is initialized through `initialize_custom_handlers` which sets up all necessary state managers and event handlers. All validation uses the validation boundary pattern for consistent error handling.

## Key Dependencies
- validation_manager: Manages form validation state
- vis_manager: Controls visualization display
- error boundaries: Provides validation and error handling
- config system: Provides validation rules, UI configuration, and demographics structure

## Branch Compatibility

This implementation supports both ryan-white and main branches through:

### Fixed Groups
- Uses predefined groups from config
- No demographic selection needed
- Group IDs come directly from config

### User-Defined Groups
- Dynamic demographic selection
- Config-driven field collection
- Abbreviated group ID generation

### Common Features
- Shared validation logic
- Config-based component handling
- Consistent input collection 