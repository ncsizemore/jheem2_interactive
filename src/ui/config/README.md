# JHEEM2 Configuration Files

This directory contains YAML configuration files that define the behavior and structure of the JHEEM2 web application.

## Core Configuration Files

### base.yaml
- Application-wide settings including name, version, theme configuration
- CSS and JavaScript file references
- Global application settings

### defaults.yaml
- Default configurations used across the application
- Model dimension mappings (must align with model's expected values)
- Input type defaults
- Selector configurations
- Abbreviation configurations for ID generation
  ```yaml
  abbreviations:
    dimensions:
      default_length: 2  # Default abbreviation length
      values:
        heterosexual_male: "hm"
        never_IDU: "nidu"
        # etc.
  ```

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
- Demographics configuration (specifies available demographic fields)
- Subgroup configuration (fixed or user-defined)
- Intervention dates and components
- Component configurations (compound or simple)
- Branch-specific settings

## Branch Compatibility

The configuration system supports different branches (e.g., main vs ryan-white) through:

### Demographic Fields
- Demographics defined in configuration, not hardcoded
- Fields and values can vary between branches
- Common input generation code works with any defined fields

### Group ID Generation
- Common abbreviation system for all demographic values
- Fixed groups use predefined IDs from config
- User-defined groups use abbreviated concatenated IDs
- Length limits enforced through abbreviations

### Component Types
- Supports both simple and compound components
- Component types and inputs defined in config
- Common handling code for all component types

## Configuration Loading

Configurations are loaded and merged in this order:
1. Base configuration (`base.yaml`)
2. Default settings (`defaults.yaml`)
3. Component configurations (`components/*.yaml`)
4. Page-specific configurations (`pages/*.yaml`)

See `src/ui/config/load_config.R` for implementation details.

## Configuration-Based Validation & Flexible Selectors

The configuration system supports flexible page requirements and optional selectors through several key features:

### Page Requirements
- Page-specific requirements are defined in `defaults.yaml` under `page_requirements`
- Each page type can specify its required configuration sections
- Requirements are validated during config loading
- Example:
  ```yaml
  page_requirements:
    prerun:
      required_sections:
        - intervention_aspects
        - population_groups
        # etc.
  ```

### Optional Selectors
- Selectors are created only if configured
- Base selector implementation (`base.R`) checks for configuration before creating
- Helper functions (e.g., `create_intervention_selector`) respect config presence
- Allows different deployments to have different UI elements without code changes

### Benefits
- Different branches/deployments can specify their own requirements
- UI elements can be added/removed via configuration
- Core functionality remains the same across deployments
- Validation is consistent but flexible

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

## Known Issues & Future Work

1. **Selector "All" Functionality**
   - Currently "all" options are removed from selectors
   - Future work needed to implement proper handling of "all" selections
   - Implementation considerations:
     * UI/UX Behavior:
       - How to handle when user selects "all" + individual options
       - Consider auto-deselecting individual options when "all" is selected
       - Consider auto-deselecting "all" when individual options are selected
       - Potentially make "all" mutually exclusive with other options
     * Model Translation:
       - Need mechanism to expand "all" into complete set of valid values
       - Consider adding expansion mappings in defaults.yaml
       - Ensure expansion respects any model-specific constraints
     * Configuration Structure:
       - May need to add metadata to identify which selectors support "all"
       - Consider adding validation rules specific to "all" handling
       - Potential for selector-specific "all" behavior
     * Performance:
       - Consider caching expanded "all" values
       - Evaluate impact on model runs with full selection sets

2. **Model Value Alignment**
   - Configuration values must align with model expectations
   - Maintain mappings in `defaults.yaml` when model values change
   - Consider adding validation to ensure config values match model requirements

## Related Files

- `src/ui/config/load_config.R`: Configuration loading and validation
- `src/ui/components/common/display/plot_controls.R`: Plot control implementation
- `app.R`: Main application file that uses these configurations