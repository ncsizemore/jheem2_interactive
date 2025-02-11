# JHEEM2 Configuration Files

This directory contains YAML configuration files that define the behavior and structure of the JHEEM2 web application.

## Core Configuration Files

### base.yaml
- Application-wide settings including name, version, theme configuration
- CSS and JavaScript file references
- Global application settings

### defaults.yaml
- Default configurations used across the application
- Model dimension mappings
- Input type defaults
- Selector configurations

## Component Configurations

Located in `components/`:

### controls.yaml
- Plot and table control settings
- Outcome selection options
- Stratification settings
- Display type configurations
- Table structure and formatting

### selectors.yaml (if applicable)
- Common selector configurations
- Reusable input settings
- Shared validation rules

## Page-Specific Configurations

Located in `pages/`:

### prerun.yaml
- Pre-run interventions page settings
- Intervention aspect selection
- Population group selection
- Timeframe and intensity settings

### custom.yaml
- Custom interventions page settings
- Subgroup configuration
- Demographic selectors
- Intervention dates and components

## Configuration Loading

Configurations are loaded and merged in this order:
1. Base configuration (`base.yaml`)
2. Default settings (`defaults.yaml`)
3. Component configurations (`components/*.yaml`)
4. Page-specific configurations (`pages/*.yaml`)

See `src/ui/config/load_config.R` for implementation details.

## Best Practices

1. **Configuration Structure**
   - Keep related settings grouped together
   - Use consistent naming conventions
   - Document any non-obvious settings

2. **Validation**
   - All configurations are validated on load
   - Required fields are checked
   - Type checking is performed where necessary

3. **Maintenance**
   - Keep configurations DRY (Don't Repeat Yourself)
   - Document changes in git commits
   - Update this README when adding new configuration types

## Related Files

- `src/ui/config/load_config.R`: Configuration loading and validation
- `src/ui/components/common/display/plot_controls.R`: Plot control implementation
- `app.R`: Main application file that uses these configurations 