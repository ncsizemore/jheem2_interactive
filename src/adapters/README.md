# Intervention Adapter Layer

## Overview
The intervention adapter layer bridges between UI settings and JHEEM2 model interventions.

### Key Components

#### intervention_adapter.R
- Main entry point for intervention creation
- Handles both custom and prerun modes
- Transforms UI settings to model format

#### model_effects.R
- Defines intervention effect configurations
- Maps UI values to model parameters
- Provides extensible effect system

### Usage

```r
# Create custom intervention
intervention <- create_intervention(settings, mode = "custom")

# Get prerun intervention
intervention <- create_intervention(settings, mode = "prerun")
```

### Configuration
Effects are configured in `model_effects.R`:
```r
MODEL_EFFECTS <- list(
    effect_name = list(
        quantity_name = "model.quantity",
        scale = "proportion|rate",
        transform = function(value) { ... },
        value_field = "ui_field_name"
    )
)
```

### Current Status
- Basic intervention creation working
- Single subgroup support
- Configuration-driven effects
- Basic error handling

### Future Work
1. Multiple subgroup support
2. Enhanced validation system
3. Better error handling
4. Population targeting
5. Prerun intervention loading

### Integration Notes
- Receives settings from UI layer
- Creates JHEEM2 interventions
- Returns intervention objects
- Will integrate with simulation runner 