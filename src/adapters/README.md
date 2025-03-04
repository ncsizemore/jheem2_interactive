# Adapter Layer

## Intervention Adapter Layer

### Overview
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

## Simulation Adapter Layer

### Overview
The simulation adapter layer manages simulation creation, execution, and state management.

### Key Components

#### simulation_adapter.R
- Main interface for simulation operations
- Coordinates with state store for simulation management
- Handles both prerun and custom modes
- Works with core simulation functionality

### Technical Details

#### Simulation State Management
Each simulation has:
- Unique ID (format: sim_{timestamp}_{random})
- Mode (prerun/custom)
- Settings used to create it
- Results containing:
  - Raw simset (for plot generation)
  - Transformed data (for table display)
- Status tracking (ready/running/complete/error)

#### Simulation Matching
- Before creating a new simulation, checks for existing simulations with matching settings
- Returns existing simulation ID if match found
- Creates new simulation only when necessary
- Optimizes performance by avoiding redundant computation

#### Error Handling

The simulation adapter includes robust error handling mechanisms:

#### Error Boundaries
- Registers error boundaries for each page
- Propagates errors from simulations to the UI
- Maintains consistent error state across views

```r
# Register an error boundary for a page
register_error_boundary = function(page_id, session, output) {
    if (!is.null(session) && !is.null(output)) {
        # Create a simulation boundary for the adapter
        private$error_boundaries[[page_id]] <- create_simulation_boundary(
            session, output, page_id, "simulation", state_manager = private$store
        )
        
        print(sprintf("[SIMULATION_ADAPTER] Registered error boundary for page %s", page_id))
    }
    invisible(self)
}
```

#### Error Processing
- Converts errors to structured format
- Preserves error message and context
- Updates simulation status to "error"
- Sets error in registered boundary

```r
# Handle simulation errors
tryCatch({
    # Simulation code
}, error = function(e) {
    # Convert error message to string
    error_message <- as.character(conditionMessage(e))
    
    # Update simulation state
    private$store$update_simulation(
        sim_id,
        list(
            status = "error",
            error_message = error_message
        )
    )
    
    # Set error in boundary
    if (!is.null(private$error_boundaries[[mode]])) {
        private$error_boundaries[[mode]]$set_error(
            message = error_message,
            type = ERROR_TYPES$SIMULATION,
            severity = SEVERITY_LEVELS$ERROR
        )
    }
    
    # Return simulation ID for proper state management
    sim_id
})
```

#### Test Error Cases
The adapter includes test cases for error handling:

- `test_error`: Forces a simulation error
- `test_existing_error`: Creates a simulation with a pre-existing error
- `test_transform_error`: Creates a simulation that will cause transform errors

These test cases can be triggered by setting `settings$location` to the corresponding value.

### Data Flow
1. UI requests simulation via adapter
2. Adapter checks for matching simulations
3. If match found, returns existing simulation ID
4. Otherwise, creates new simulation and updates state in store
5. Raw simset used directly for plots
6. Transformed data used for tables
7. State tracked to avoid unnecessary re-runs

#### Integration with Core Layer
- Uses SimulationRunner from core layer
- Maintains provider configuration
- Handles intervention application
- Preserves core simulation functionality 