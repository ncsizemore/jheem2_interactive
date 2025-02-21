# Intervention Adapter Layer

## Overview
The intervention adapter layer bridges between UI settings and JHEEM2 model interventions.

### Key Components

#### intervention_adapter.R
- Main entry point for intervention creation
- Handles both custom and prerun modes
- Transforms UI settings to model format
- Uses `join.interventions()` to combine multiple subgroup interventions
- Handles both fixed and user-defined groups
- Supports compound components with different input types (numeric, select)

#### model_effects.R
- Defines intervention effect configurations
- Maps UI values to model parameters
- Provides extensible effect system
- Branch-specific configuration for model quantities

### Technical Details

#### Multiple Subgroup Handling
Each subgroup can have its own target population and effects. The adapter:
1. Creates separate interventions per subgroup
2. Uses `join.interventions()` to combine them safely
3. Avoids conflicts when multiple subgroups affect the same quantity

```r
# Example: Different testing frequencies for different populations
subgroup1 <- create.intervention(young_msm, testing_twice_yearly)
subgroup2 <- create.intervention(older_hetero, testing_once_yearly)
combined <- join.interventions(subgroup1, subgroup2)
```

#### Intervention Codes
- Limited to 25 characters
- Format: `c.{session_id}.{timestamp}[.{subgroup}]`
- Example: `c.12345678.02051123.1`
- Session ID required for concurrent user support
- Timestamp ensures uniqueness within session

#### Target Population Names
- Limited to 30 characters
- Uses configurable abbreviations from defaults.yaml
- Format for user-defined groups: `dim1-dim2-dimN` with abbreviated values
- Format for fixed groups: Uses predefined group IDs from config
- Example: "hm-b-nidu-1324" for "heterosexual male, black, never IDU, age 13-24"
- Abbreviations are configuration-driven and customizable

#### Component Value Collection
- Supports both numeric and select input types
- For compound components:
  - Handles enabled/disabled state
  - Collects values from first non-enabled input
  - Supports different input types within compound components
  - Preserves selected values in settings collection

#### Effect Creation
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

### Important Implementation Notes
1. Each target population can only have one effect per quantity type
2. `join.interventions()` handles merging target populations and effects correctly
3. Dates must be converted to numeric values
4. Empty or disabled interventions return a null intervention
5. Always pass session ID when creating interventions in multi-user context

### Future Work
1. Multiple subgroup support ✓
2. Enhanced validation system
3. Better error handling
4. Population targeting
5. Prerun intervention loading

### Integration Notes
- Receives settings from UI layer
- Creates JHEEM2 interventions
- Returns intervention objects
- Will integrate with simulation runner

### Key References
- `six_basic_interventions.R` - Example intervention patterns
- JHEEM2 intervention documentation
- `join.interventions()` documentation for combining interventions

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
- Multiple subgroup support ✓
- Concurrent user support via session IDs ✓
- Configuration-driven effects ✓
- Basic error handling ✓

### Future Work
1. Enhanced validation system
2. Better error handling
3. Population targeting
4. Prerun intervention loading

### Integration Notes
- Receives settings from UI layer
- Creates JHEEM2 interventions
- Returns intervention objects
- Will integrate with simulation runner 