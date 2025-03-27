# Data Loaders

This directory contains specialized data loading utilities for the JHEEM2 application.

## baseline_loader.R

The `baseline_loader.R` file provides functionality for loading baseline (no intervention) simulations for comparison purposes.

### Overview

The baseline loader:
- Loads baseline simulations based on configuration settings
- Supports both prerun and custom intervention modes
- Uses the appropriate provider (local or OneDrive) based on configuration
- Handles error cases gracefully

### Key Function

```r
load_baseline_simulation <- function(page_id, settings) { ... }
```

**Parameters:**
- `page_id`: Either "prerun" or "custom", indicating which page is loading the baseline
- `settings`: Settings object that contains at minimum a `location` field

**Returns:**
- A JHEEM2 simulation set object for the baseline, or `NULL` if unavailable

### Configuration

The baseline loader uses the visualization configuration, specifically the `baseline_simulations` section:

```yaml
# Baseline simulations configuration
baseline_simulations:
  enabled: true
  # Global settings that apply to both prerun and custom
  default_file_pattern: "base/{location}_base.Rdata"
  
  # Labels support template tags like {location}
  default_label: "Baseline (No Intervention)"
  intervention_label: "Intervention ({location})"
  
  # Visual styling for baseline vs. intervention plots
  plot_styles:
    baseline:
      color: "#0072B2"  # Blue
      alpha: 0.9
    intervention:
      color: "#D55E00"  # Orange
      alpha: 1.0
    use_different_line_types: false
  
  # Page-specific settings
  prerun:
    enabled: true
    # Use provider from page config
    use_provider: true
    
  custom:
    enabled: true
    # For custom, we can choose to reuse the base simulation
    reuse_base_simset: true
```

This allows for flexible configuration:
- Global enable/disable
- Per-page enable/disable
- Custom file patterns
- Custom labels for display with template support
- Custom styling for baseline vs. intervention plots
- Provider selection

### Integration

The baseline loader is used in `plot_panel.R` to load baseline simulations for comparison with interventions. For custom interventions, it works with the `get_original_base_simulation` method from the state store.

Usage pattern:
```r
# Attempt to get original base simulation
baseline_simset <- NULL
if (id == "custom") {
  baseline_simset <- store$get_original_base_simulation(id)
}

# Fallback to loading from file if needed
if (is.null(baseline_simset)) {
  baseline_simset <- load_baseline_simulation(id, sim_settings)
}
```

### Error Handling

The loader handles several error conditions:
- Missing location in settings
- Missing or invalid configuration
- Provider creation failures
- Simulation loading failures

In all cases, it returns `NULL` rather than throwing an error, allowing the calling code to handle the absence of a baseline appropriately.
