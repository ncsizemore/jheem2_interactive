# Plotly Adapters

This directory contains temporary local implementations of jheem2 plotly functions that will be used until the updated versions are merged into the main jheem2 branch.

## Overview

The `plotly_plot_adapter.R` file contains local versions of:
- `fixed_plot_simulations`: A local version of plot.simulations
- `fixed_execute_plotly_plot`: A local version of execute.plotly.plot

These implementations include fixes for faceting and other display issues that will eventually be part of the main jheem2 package.

## How to Use

The plot_panel.R file includes a flag:

```r
# Flag to control which plotting approach to use
# Set to TRUE to use direct plotly generation
# Set to FALSE to use simplot + ggplotly conversion
USE_DIRECT_PLOTLY <- TRUE
```

Control this flag to switch between:
- `TRUE`: Uses the local fixed plotly functions for direct plotly generation
- `FALSE`: Uses the simplot + ggplotly conversion approach

## Transitioning to Package Version

When the updated plotly functions are merged into the main jheem2 branch:

1. Update the `USE_DIRECT_PLOTLY` flag section in plot_panel.R to use the package functions instead of the local ones:

```r
if (USE_DIRECT_PLOTLY) {
  # Use jheem2 package direct plotly generation
  plot <- plot.simulations(
    simset,
    outcomes = current_settings$outcomes,
    facet.by = current_settings$facet.by,
    summary.type = current_settings$summary.type,
    style.manager = default_plotly_style
  )
}
```

2. Test thoroughly with the package versions to ensure they work as expected.

3. Once confirmed working, you can remove:
   - The local adapter files
   - The USE_DIRECT_PLOTLY flag
   - The conditional logic in plot_panel.R
