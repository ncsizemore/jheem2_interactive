# Section Builder Module - Developer Documentation

This documentation covers the section builder system from a developer's perspective, explaining how it works internally, how to maintain it, and potential improvements.

## Overview

The section builder system provides a flexible way to organize UI selectors into visual sections with headers and descriptions. It's built to be:
- Configuration-driven through YAML files
- Backward compatible with existing deployments
- Error-resilient with proper fallback mechanisms
- Adaptable to different branches and use cases

## Key Components

### Files

- **section_builder.R**: Core module that builds sections from configuration
- **section_header.R**: Component for creating section headers
- **section_errors.css**: CSS styles for error handling
- **defaults.yaml**: Default section configurations

### Core Functions

- **create_sections_from_config()**: Main entry point for section creation
- **build_sections_internal()**: Internal implementation of section building
- **create_fallback_sections()**: Generates fallback UI in case of errors
- **validate_section_config()**: Validates section configurations

## How Section Building Works

The section building process follows these steps:

1. **Configuration Loading**: Loads section and selector configurations from YAML
2. **Section Creation**: For each configured section, creates the corresponding UI elements
3. **Selector Association**: Associates selectors with their respective sections
4. **Fallback Handling**: Creates fallback sections for any unassigned selectors
5. **Error Handling**: Provides error recovery and user feedback

## Code Flow Walkthrough

```
create_sections_from_config()  # Entry point with error handling
  ↓
build_sections_internal()  # Core section building logic
  ↓
validate_section_config()  # Validates configuration
  ↓
create_selector()  # Creates each selector
  ↓
create_section_header()  # Creates section headers
```

## Integration with Pages

The section builder is used in both prerun and custom pages:

```r
# In pages/prerun/content.R and pages/custom/content.R
section_result <- create_sections_from_config(
    config = config, 
    page_type = "prerun",  # or "custom"
    session = session,
    output = output
)
```

## Error Handling System

The section builder integrates with JHEEM2's dual-layer error system:

1. **Error Boundaries**: Creates error boundaries for structured error handling
2. **Direct Text Output**: Provides direct text error messages
3. **Fallback UI**: Generates working fallback UI when errors occur

## Maintainability Considerations

### Adding New Selector Types

To support a new selector type:

1. Add the type to `input_types` in defaults.yaml
2. Handle the new type in `create_input_by_type()` in base.R
3. Update section builder to properly group the new type

### Supporting Special Components

Some UI components (like date ranges in the custom page) require special handling:
- They're detected through specific configuration paths (e.g., `config$interventions$dates`)
- They're rendered with specialized UI code
- They can be incorporated into sections through configuration

### Branch-Specific Customizations

Different branches can customize sections by:
- Defining different section configurations in their YAML files
- Adding branch-specific selectors
- Customizing section titles and descriptions

## Potential Improvements

### Code Structure

- **Better Modularization**: The core selector creation logic could be more modular
- **YAML Schema Validation**: Add formal schema validation for configuration files
- **Selector Registry**: Create a registry of selector creation functions for cleaner mapping

### Performance

- **Caching**: Cache section generation for unchanging configurations
- **Lazy Rendering**: Implement lazy rendering for selectors that aren't immediately visible
- **Reduce DOM Size**: Optimize the generated DOM structure for better performance

### UI Enhancements

- **Collapsible Sections**: Allow sections to be collapsed/expanded
- **Drag-and-Drop Ordering**: Let users reorder sections
- **Visual Indicators**: Add visual cues for required vs. optional selectors
- **Responsive Design**: Improve layout for different screen sizes

### Testing

- **Unit Tests**: Add tests for section building and error handling
- **Visual Regression Tests**: Add tests to verify UI layout
- **Configuration Validators**: Add validators to catch common configuration errors

## Code Structure Details

### Section Builder Internal Data Flow

The section builder maintains several internal state variables:
- `sections`: Dictionary of sections being built
- `all_selectors`: List of all configured selectors
- `assigned_selectors`: Tracking which selectors have been assigned to sections

### Error Handling Strategy

The error handling follows a "graceful degradation" approach:
1. First, attempt to build the full section structure
2. If errors occur, catch them and log warnings
3. Create a simplified fallback UI
4. Provide user feedback about the error
5. Allow the application to continue functioning

## Dependencies

The section builder depends on:
- Shiny for UI components
- YAML for configuration parsing
- `%||%` operator for NULL handling
- Error boundaries system for error handling

## Performance Considerations

The section builder may introduce some overhead due to:
- Configuration validation
- Multiple passes through selector lists
- Error boundary creation

However, this overhead should be minimal for most deployments, as the section building happens once during page initialization.

## Code Maintenance Guidelines

When modifying the section builder:

1. Maintain backward compatibility
2. Preserve the configuration-driven approach
3. Handle errors gracefully
4. Add clear documentation for changes
5. Keep styling in CSS files, not inline styles
6. Test thoroughly, especially with edge cases
