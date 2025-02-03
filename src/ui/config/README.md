# JHEEM2 Configuration Files

This directory contains YAML configuration files that define the behavior and structure of the JHEEM2 web application.

## Core Configuration Files

### base.yaml
- Application-wide settings including name, version, theme configuration
- CSS and JavaScript file references
- **Note**: Contains duplicate caching config that should be consolidated with `caching.yaml`

### defaults.yaml
- Default configurations used across the application
- Panel and display defaults
- Plot control configurations
- Input type defaults
- Selector configurations
- **Improvement**: Could be split into smaller, more focused files

### caching.yaml
- Cache size and eviction strategy settings
- Used by the application's caching system
- **Note**: Should be consolidated with caching config in `base.yaml`

### controls.yaml
- Plot control settings
- Dimension settings for faceting/stratification
- Table display settings
- **Improvement**: Some settings overlap with `defaults.yaml` and should be consolidated

## Page-Specific Configurations

### prerun.yaml
- Settings for pre-run interventions page
- Intervention aspect selection
- Population group selection
- Timeframe and intensity settings

### custom.yaml
- Custom interventions page settings
- Subgroup configuration
- Demographic selectors
- Intervention dates and components

### Static Page Configurations
- `about.yaml`: About page content and structure
- `contact.yaml`: Contact form configuration
- `overview.yaml`: Overview page layout and content
- `team.yaml`: Team member information and layout

## Opportunities for Improvement

1. **Configuration Consolidation**
   - Merge duplicate caching settings
   - Consolidate overlapping control settings
   - Consider merging static page configs into a single file

2. **Structure Optimization**
   - Split `defaults.yaml` into more focused files
   - Create a clear hierarchy for configuration inheritance
   - Consider using JSON Schema for validation

3. **Documentation**
   - Add detailed comments for each configuration section
   - Document relationships between configuration files
   - Create examples for common configuration patterns

4. **Validation**
   - Implement schema validation for each config file
   - Add type checking for critical values
   - Create tests for configuration loading

## Usage

These configuration files are loaded by `src/ui/config/load_config.R`, which provides functions to:
- Load individual config files
- Merge configurations
- Validate configuration structure
- Access specific configuration values

## Related Files

- `src/ui/config/load_config.R`: Configuration loading and validation
- `app.R`: Main application file that uses these configurations 