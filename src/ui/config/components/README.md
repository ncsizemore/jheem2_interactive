# Component Configuration Files

This directory contains YAML configuration files for specific components of the JHEEM2 application.

## Current Configuration Files

### caching.yaml
- Disk cache settings for application data
- Cache size limits
- Eviction strategy configurations

### controls.yaml
- Plot and table control settings
- Outcome selection options
- Stratification settings
- Display type configurations

### state_management.yaml
- Simulation state management configuration
- Cleanup strategy parameters
- Memory management settings
- Parameters include:
  - `default_max_age`: Standard maximum age (in seconds) before a simulation is considered old and eligible for cleanup (default: 1800 seconds / 30 minutes)
  - `cleanup_interval`: How often the cleanup process runs (in milliseconds) (default: 600000 ms / 10 minutes)
  - `high_count_threshold`: Number of simulations that triggers aggressive cleanup (default: 20)
  - `aggressive_max_age`: Maximum age during aggressive cleanup (in seconds) (default: 900 seconds / 15 minutes)

## Usage

These configuration files are loaded by the `get_component_config()` function in `src/ui/config/load_config.R`. To access a specific component's configuration:

```r
# Get control component config
control_config <- get_component_config("controls")

# Get state management config
state_config <- get_component_config("state_management")
```

## Modifying Configurations

Parameters can be adjusted by modifying the YAML files. Changes will take effect when the application is restarted.

### Example: Adjusting State Cleanup

To adjust how aggressively old simulations are cleaned up, modify the parameters in `state_management.yaml`:

```yaml
# More aggressive cleanup
cleanup:
  default_max_age: 900  # 15 minutes
  high_count_threshold: 10
  aggressive_max_age: 300  # 5 minutes
```

```yaml
# Less aggressive cleanup
cleanup:
  default_max_age: 3600  # 60 minutes
  high_count_threshold: 30
  aggressive_max_age: 1800  # 30 minutes
```
