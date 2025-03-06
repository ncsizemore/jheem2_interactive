# JHEEM2 Data Layer

This directory contains components related to data storage, loading, caching, and providing data to the application UI. The data layer is responsible for managing simulation data and ensuring efficient access to simulations.

## Architecture Overview

The JHEEM2 data layer follows a provider-based architecture with the following key components:

1. **Provider Interface**: Defines standard methods for loading and storing simulation data
2. **Concrete Providers**: Implementations for specific storage backends (LocalProvider, OneDriveProvider, etc.)
3. **Cache System**: Disk-based caching of simulation results to prevent redundant computation
4. **Loader**: Central access point for loading simulations across the application
5. **Utility Functions**: Common utilities for data operations

## Provider System (`providers/`)

The provider system abstracts data storage and retrieval operations, allowing multiple back-end implementations.

### Provider Interface

The base `Provider` class defines the contract all providers must implement:

```r
# Key methods in the Provider interface
Provider$load_simset(settings)      # Load a simulation set based on settings
Provider$save_simset(simset, key)   # Save a simulation set with a given key
Provider$list_available()           # List available simulations
```

### Available Providers

1. **LocalProvider** (`local_provider.R`): 
   - Loads and saves simulations from the local file system
   - Organizes files based on simulation parameters

2. **OneDriveProvider** (`onedrive_provider.R`):
   - Integration with Microsoft OneDrive for cloud storage
   - Handles authentication and synchronization

3. **AWS Provider** (`aws_provider.R`):
   - Placeholder for future AWS S3 integration
   - Not fully implemented yet

## Cache Module (`cache.R`)

The cache module provides disk-based caching capabilities for the application. It improves performance by preventing unnecessary re-running of simulations.

### Key Components

1. **Initialization**:
   ```r
   # Initialize caches with configuration
   initialize_caches(config)
   ```

2. **Simulation Cache**:
   ```r
   # Check if a simulation is cached
   is_simulation_cached(settings, mode)

   # Get a simulation from cache
   get_simulation_from_cache(settings, mode, check_version = TRUE)

   # Cache a simulation
   cache_simulation(settings, mode, sim_state, ttl = NULL)
   ```

3. **Cache Management**:
   ```r
   # Get cache statistics
   get_cache_stats()

   # Clean up old simulations
   cleanup_simulation_cache(max_age = NULL, dry_run = FALSE)
   
   # Debug cache functionality
   debug_cache_key(settings, mode)
   dump_cache_info()
   ```

### Cache Implementation Details

1. **Storage Format**:
   - Each cached simulation is stored as an `.RData` file
   - Associated metadata is stored in a separate `.meta` file
   - Cache keys are generated using a deterministic algorithm based on simulation settings

2. **Location Normalization**:
   - Location codes are normalized for consistency
   - Prevents duplicate cache entries due to trivial differences in location format

3. **Version Compatibility**:
   - Cache includes version information to prevent compatibility issues
   - Optional version checking can be enabled/disabled in configuration

4. **Automatic Cleanup**:
   - Older cache entries can be automatically removed
   - Configurable time-to-live (TTL) for cache entries

5. **Cache Mode Optimization**:
   - Optimized to skip caching for pre-run simulations
   - Focuses caching on custom simulations that are more expensive to generate

### Configuration

Cache behavior is controlled via `src/ui/config/components/caching.yaml`:

```yaml
simulation_cache:
  enable_disk_cache: true    # Enable/disable disk caching
  max_size: 2000000000       # 2GB max cache size
  evict_strategy: "lru"      # Least Recently Used eviction
  path: "cache/simulations"  # Where to store cache files
  ttl: 604800               # Time-to-live in seconds (7 days)
  simulation_version: "ehe"  # Version tag for cache invalidation
  check_version: true        # Whether to check version compatibility
  provider: "disk"           # Storage provider (disk, onedrive, aws)
```

## Loader (`loader.R`)

The loader module centralizes access to simulation data across the application:

```r
# Initialize provider (typically called at app startup)
initialize_provider(provider_type = "local", ...)

# Load a simulation set
load_simset(simset_key)
```

## Prerun Library (`prerun_library.R`)

The prerun library module manages pre-computed simulations:

1. **Simulation Discovery**: Finds available pre-run simulations
2. **Parameter Extraction**: Extracts parameters from pre-run simulation metadata
3. **Filtering & Sorting**: Organizes simulations by location, category, etc.

## Utilities (`utils.R`)

Common utility functions for data operations:

```r
# Normalize location code format for consistency
normalize_location_code(location_code)
```

## Integration with State Management

The data layer integrates with the application's state management system:

1. **Finding Simulations**:
   - The StateStore first checks in-memory simulations
   - Then checks the disk cache for matching simulations
   - Finally runs a new simulation if necessary

2. **Storing Simulations**:
   - When a new simulation is created, it's stored in memory
   - Also cached to disk if disk caching is enabled

## Error Handling

The data layer includes comprehensive error handling:

1. **Graceful Degradation**:
   - Cache operations fail gracefully, allowing the application to continue
   - Multiple fallback mechanisms for path resolution

2. **Detailed Logging**:
   - Extensive debug logging for troubleshooting
   - Log format includes component tags (e.g., `[CACHE]`, `[STATE_STORE]`)

3. **Error Classification**:
   - Cache errors are identified as `ERROR_TYPES$SIMULATION_CACHE`
   - Non-critical errors typically use `SEVERITY_LEVELS$WARNING`

## Future Extensions

The data layer is designed with extensibility in mind:

1. **Cloud Integration**:
   - OneDrive provider implementation
   - AWS S3 or other cloud storage backends

2. **Enhanced Cache Features**:
   - More sophisticated cache invalidation strategies
   - Better compression for large simulations

3. **Distributed Caching**:
   - Potential for shared caches across multiple application instances
   - Optimizations for collaborative environments

## Troubleshooting

If data access or caching issues occur:

1. **Configuration**:
   - Check if the simulation cache is enabled in the configuration
   - Verify the provider type is set correctly

2. **File System**:
   - Verify cache directory exists and has proper permissions
   - Check available disk space for cache storage

3. **Diagnostics**:
   - Run `test_cache_functionality()` to validate cache operations
   - Use `debug_cache_key(settings, mode)` to debug specific cache issues
   - Use `dump_cache_info()` to inspect cache contents

4. **Common Issues**:
   - Path resolution problems: Check for valid cache directory paths
   - Version mismatch: Verify simulation version settings
   - .rds files: If unexpected .rds files appear, they should be auto-cleaned

## Notes on Large Simulations

For simulations larger than 200-300MB:

1. **Storage Considerations**:
   - The cache module will attempt to store them, but performance may vary
   - Consider adjusting max_size in the configuration
   - The cache may automatically evict large simulations based on LRU policy

2. **Performance Tips**:
   - Monitor memory usage when loading large simulations
   - Consider using the prerun library for frequently used large simulations