# JHEEM2 UI Configuration System

This guide explains the configuration system for JHEEM2, focusing on how to use YAML files to customize the UI and application behavior.

## Overview

The JHEEM2 configuration system is built around YAML files that define everything from UI elements to application behavior. This approach allows for customization without code changes, making it ideal for branch-specific deployments.

The configuration system is implemented in `src/ui/config/load_config.R`, which provides functions for loading and merging configuration files.

## Configuration Structure

The configuration system is organized in a hierarchical structure:

```
src/ui/config/
├── base.yaml              # Core application settings
├── defaults.yaml          # Default values and shared configurations
├── components/            # Component-specific configurations
│   ├── caching.yaml       # Cache settings
│   ├── controls.yaml      # Plot and table controls
│   └── state_management.yaml  # State management parameters
└── pages/                 # Page-specific configurations
    ├── prerun.yaml        # Pre-run interventions page
    ├── custom.yaml        # Custom interventions page
    └── ...                # Other pages
```

## Key Configuration Files

- **base.yaml**: Core application settings
- **defaults.yaml**: Default configurations that apply across the application
- **pages/prerun.yaml**: Configuration specific to the Pre-run Interventions page
- **pages/custom.yaml**: Configuration specific to the Custom Interventions page

## Loading Configuration

The configuration system uses these key functions:

- `get_base_config()`: Loads the base application configuration
- `get_defaults_config()`: Loads default values and settings
- `get_component_config(component)`: Loads configuration for a specific component
- `get_page_config(page)`: Loads configuration for a specific page
- `get_page_complete_config(page)`: Loads complete configuration for a page by merging several configuration files

Example usage in code:
```r
# Load configuration for plots component
plot_config <- get_component_config("plots")

# Load complete configuration for prerun page
prerun_config <- get_page_complete_config("prerun")
```

## Configuring UI Sections

Sections allow you to group related selectors with visual headers and descriptions. They're defined in the `sections` block of your YAML file:

```yaml
# Section configurations
sections:
  location:
    title: "Location"
    description: "Select the geographic area for the model"
    selectors: ["location"]
  intervention:
    title: "Intervention"
    description: "Choose intervention parameters"
    selectors: ["intervention_aspects", "population_groups", "timeframes", "intensities"]
```

The section building is handled by the `create_sections_from_config()` function in `src/ui/components/common/layout/section_builder.R`.

### Section Properties

| Property | Description | Required | Code Reference |
|----------|-------------|----------|----------------|
| `title` | Header text displayed at the top of the section | Yes | Used in `create_section_header()` |
| `description` | Explanatory text displayed below the header | No | Used in `create_section_header()` |
| `selectors` | Array of selector IDs to include in this section | No | Used in `build_sections_internal()` |

## Configuring Selectors

Selectors are the interactive UI elements like dropdowns, radio buttons, etc. They're defined in the `selectors` block:

```yaml
selectors:
  location:
    type: "select"
    label: "Location"
    description: "Select the geographic area for the model"
    show_label: true
    placeholder: "Select a location..."
    value: "C.33100"  # Default value
    options:
      atlanta:
        id: "C.12580"
        label: "Atlanta-Sandy Springs-Roswell, GA"
      miami:
        id: "C.33100"
        label: "Miami-Fort Lauderdale-Pompano Beach, FL"
```

Selectors are created by the `create_selector()` function in `src/ui/components/selectors/base.R`.

### Selector Properties

| Property | Description | Required | Code Reference |
|----------|-------------|----------|----------------|
| `type` | Type of selector ("select", "radio", "checkbox", "numeric") | Yes | Used in `create_input_by_type()` |
| `label` | Text label for the selector | Yes | Passed to the appropriate input function |
| `description` | Explanatory text displayed below the label | No | Used in `choicesSelectInput()` |
| `show_label` | Whether to show the label (default: true) | No | Used in `choicesSelectInput()` |
| `placeholder` | Placeholder text for empty selectors | No | Passed to input function |
| `value` | Default selected value | No | Sets the initial selection |
| `options` | Available options for the selector | Yes (for select/radio) | Used to build choices |
| `input_style` | UI style to use (e.g., "choices" for Choices.js) | No | Determines which input function to use |
| `multiple` | Whether multiple selections are allowed | No | Configures selection mode |

## Component Configurations

Component-specific configurations are stored in the `components/` directory:

### Caching (caching.yaml)
Configure disk caching for application data:
```yaml
cache1:
  max_size: 500MB
  evict_strategy: "lru"
```

### Controls (controls.yaml)
Configure plot and table control options:
```yaml
plot_controls:
  outcomes:
    type: "checkbox"
    label: "Outcomes"
    options:
      ...
```

### State Management (state_management.yaml)
Configure simulation state management:
```yaml
cleanup:
  default_max_age: 1800  # 30 minutes
  cleanup_interval: 600000  # 10 minutes
  high_count_threshold: 20
```

## Example: Adding a New Selector

To add a new selector and place it in a section:

1. Add the selector definition:

```yaml
selectors:
  my_new_selector:
    type: "select"
    label: "My New Selector"
    description: "Description of what this selector does"
    options:
      option1:
        id: "option1"
        label: "Option 1"
      option2:
        id: "option2"
        label: "Option 2"
```

2. Add it to a section (or create a new section):

```yaml
sections:
  my_section:
    title: "My Section"
    description: "Section containing my new selector"
    selectors: ["my_new_selector"]
```

## Panel Configuration

Panels are the larger containers that hold sections and selectors. You can configure their headers and descriptions:

```yaml
panels:
  left:
    id: "intervention-panel"
    header: "Specify Intervention"
    description: "Select options below to configure the intervention settings."
    width: 300
    collapsible: true
    defaultVisible: true
```

Panel creation is handled by the `create_panel()` function in `src/ui/components/common/layout/panel.R`.

## Configuration Merging

Configurations are merged hierarchically:
1. Base configuration (`base.yaml`)
2. Default configuration (`defaults.yaml`)
3. Component configurations (from `components/`)
4. Page-specific configuration (from `pages/`)

This allows for overriding settings at different levels of specificity.

The merging is handled by the `merge_configs()` function in `load_config.R`.

## Tips for Configuration

- **Backward Compatibility**: If you don't specify `selectors` for a section, all selectors will still appear but without organization
- **Selector Assignment**: A selector can only be assigned to one section
- **Unassigned Selectors**: Any selectors not explicitly assigned to a section will appear in an "Additional Settings" section
- **Visibility**: Selectors that aren't configured won't appear at all
- **Branch-Specific Config**: For branch-specific deployments, create branch-specific YAML files
- **Error Handling**: The section builder includes error handling to ensure a working UI even if configuration has errors

## Validation and Error Handling

The configuration system includes validation to ensure that required settings are present:
- `validate_config()` in `load_config.R` checks for required sections
- `validate_page_config()` checks page-specific requirements
- `validate_section_config()` in `section_builder.R` validates section configurations

If errors occur during section building, a fallback UI is displayed with error messages.

## Testing Your Configuration

After making changes to the YAML files:

1. Restart the application
2. Check that all selectors appear in the expected sections
3. Verify that labels and descriptions are displayed correctly
4. Test that default values are selected

If you encounter issues:
- Check the application logs for error messages
- Look for error messages in the UI (from the error handling system)
- Verify YAML syntax with a YAML validator

## Advanced Configuration

### Custom Input Types

You can configure default settings for different input types:

```yaml
input_types:
  select:
    default_style: "choices"
    multiple: false
  radio:
    default_style: "native"
    multiple: false
```

### Model Dimension Mappings

Configure mappings between UI values and model values:

```yaml
model_dimensions:
  age:
    ui_field: "age_groups"
    mappings:
      "13-24": "13-24 years"
      "25-34": "25-34 years"
```

### Page Requirements

Define which settings are required for each page type:

```yaml
page_requirements:
  prerun:
    required_sections:
      - intervention_aspects
      - population_groups
```

## Related Code Files

The configuration system interacts with these key files:

- `src/ui/config/load_config.R`: Core configuration loading functions
- `src/ui/components/common/layout/section_builder.R`: Creates UI sections from config
- `src/ui/components/common/display/section_header.R`: Creates section headers
- `src/ui/components/selectors/base.R`: Creates selectors based on configuration
- `src/ui/components/selectors/choices_select.R`: Creates Choices.js select inputs
- `src/ui/components/common/layout/panel.R`: Creates panels based on configuration
- `src/ui/components/pages/prerun/content.R`: Uses section builder for prerun page
- `src/ui/components/pages/custom/content.R`: Uses section builder for custom page
