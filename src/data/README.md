# JHEEM2 Data Layer

This directory contains components related to data storage, caching, and providing data to the UI.

## Cache Module (cache.R)

The cache module provides disk-based caching capabilities for the application. It includes:

1. **Simulation Caching**: Prevents unnecessary re-running of simulations by storing results on disk
2. **Version-aware Storage**: Includes app version in cache keys to prevent compatibility issues
3. **Error-handling**: Graceful degradation when cache operations fail
4. **Backward Compatibility**: Legacy functions to support existing code

### Key Functions

#### Initialization
```r
# Initialize caches with configuration
initialize_caches(config)
```

#### Simulation Cache
```r
# Check if a simulation is cached
is_simulation_cached(settings, mode)

# Get a simulation from cache
get_simulation_from_cache(settings, mode)

# Cache a simulation
cache_simulation(settings, mode, sim_state, ttl = NULL)
```

#### Utilities
```r
# Get cache statistics
get_cache_stats()

# Test cache functionality
test_cache_functionality()
```

### Configuration

Cache behavior is controlled via `src/ui/config/components/caching.yaml`:

```yaml
simulation_cache:
  enable_disk_cache: true  # Enable/disable disk caching
  max_size: 2000000000     # 2GB max cache size
  evict_strategy: "lru"    # Least Recently Used eviction
  path: "cache/simulations"
  ttl: 604800             # Time-to-live in seconds (7 days)
  app_version: "1.0.0"    # App version for cache invalidation
```

### Testing

Basic cache testing can be performed by running:

```r
source("src/tests/test_disk_cache.R")
```

## Integration with State Management

The cache module integrates with the application's state management system in two ways:

1. **Finding Simulations**: When looking for a simulation, the StateStore first checks in-memory simulations, then the disk cache
2. **Storing Simulations**: When a new simulation is created, it's stored in both memory and the disk cache

## Error Handling

Cache operations use the application's error handling system:

1. **Non-critical Errors**: Cache operations fail gracefully, allowing the application to continue
2. **Error Types**: Cache errors are identified as `ERROR_TYPES$SIMULATION_CACHE`
3. **Error Severity**: Cache errors typically use `SEVERITY_LEVELS$WARNING` since they don't prevent functionality

## Future Extensions

The caching system is designed to be extensible for future needs:

1. **Cloud-based Caching**: The architecture allows for adding AWS S3 or other cloud storage backends
2. **Pre-run Integration**: Can be enhanced to work with pre-run simulations from cloud storage
3. **Enhanced Compression**: Can implement more sophisticated compression for large simulations

## Notes on Large Simulations

For simulations larger than 200-300MB:

1. The cache module will attempt to store them, but performance may vary
2. Consider enabling cache compression in the configuration
3. The cache may automatically evict large simulations based on LRU policy

## Troubleshooting

If caching issues occur:

1. Check if the simulation cache is enabled in the configuration
2. Verify that the cache directory exists and has proper permissions
3. Run the cache tests to validate functionality
4. Check available disk space if caching large simulations
