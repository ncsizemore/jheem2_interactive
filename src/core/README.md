# JHEEM2 Core Components

## Architecture Overview

The core layer handles simulation execution and data transformation, serving as a bridge between the data layer and the UI/adapter layers.

### Key Components

#### Simulation Runner (`simulation/runner.R`)
Manages the execution of simulations and interventions.

```r
# Basic usage
runner <- SimulationRunner$new(provider)
simset <- runner$load_simset("simulation_key")
results <- runner$run_intervention(intervention, simset)
```

Key responsibilities:
- Loading simulation sets via data provider
- Running individual interventions
- Running multiple interventions as scenarios
- Error handling and validation

#### Results Transformer (`simulation/results.R`)
Transforms simulation data for visualization and analysis.

```r
# Transform data for plotting
results <- transform_simulation_data(simset, settings = list(
    outcomes = c("incidence", "prevalence"),
    facet.by = c("age", "race"),
    summary.type = "mean"
))
```

Key responsibilities:
- Converting simulation data to visualization-ready format
- Applying dimension-based faceting
- Calculating summary statistics

### Layer Interactions

```
UI Layer
   ↓ ↑
Adapter Layer (translates UI inputs to model format)
   ↓ ↑
Core Layer (runner.R, results.R)
   ↓ ↑
Data Layer (providers)
```

1. **UI → Core**: 
   - Requests simulation runs
   - Specifies data transformations
   - Receives formatted results

2. **Core → Data**:
   - Loads simulation sets
   - Retrieves model specifications
   - Manages data persistence

3. **Core → Adapter**:
   - Provides dimension information
   - Validates intervention specifications
   - Returns execution results

## Model Dimensions and Specifications

### Inspecting Model Dimensions

To inspect the available dimensions for a simulation set:

```r
# 1. Load a simulation set
simset <- load_simset("your_simset_key")

# 2. Access specification metadata
spec_metadata <- simset$jheem.kernel$specification.metadata

# 3. View available dimensions and their values
dim_names <- spec_metadata$dim.names
str(dim_names)  # Shows all dimensions and their valid values

# Example output structure:
# List of 18
#  $ location      : chr "C.12580"
#  $ age           : chr [1:5] "13-24 years" "25-34 years" ...
#  $ race          : chr [1:3] "black" "hispanic" "other"
#  $ sex           : chr [1:3] "heterosexual_male" "msm" "female"
#  $ risk          : chr [1:3] "never_IDU" "active_IDU" "IDU_in_remission"
#  $ continuum     : chr [1:4] "undiagnosed_acute" ...
#  ...
```

### Important Notes

1. Dimensions can vary based on model specification version
2. Age groups can be referenced by either:
   - Index (1-based): `c(1)` for first age group
   - Full string: `"13-24 years"`
3. Some dimensions combine multiple concepts (e.g., `sex` includes both biological sex and sexual orientation)
4. When creating interventions, always verify dimensions against the specific simulation set being used

### Related Files
- `src/core/simulation/runner.R` - Handles simulation execution
- `src/adapters/intervention_adapter.R` - Translates UI settings to model format 