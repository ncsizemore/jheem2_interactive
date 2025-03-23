# Unified Cache Manager

The Unified Cache Manager system provides a centralized approach to caching in the JHEEM application, addressing issues with disk space management and memory pressure.

## Overview

The system is designed to solve several key problems:

1. **Independent Caching Systems**: Previously, OneDrive cache and simulation cache operated independently, leading to inefficient space usage.
2. **Disk Space Management**: No system was checking available disk space or handling disk-full scenarios.
3. **Memory Management**: No adaptive approach to memory pressure existed.
4. **Uncoordinated Cleanup**: Each cache managed its own cleanup with no awareness of the overall system.

## Files

- `manager.R` - Core implementation of the UnifiedCacheManager class
- `helpers.R` - Helper functions for accessing the cache manager

## Class Documentation

The `UnifiedCacheManager` class is an R6 class with the following structure:

### Public Methods

#### Initialization
- `initialize(config)` - Initializes the cache manager with configuration

#### Path Accessor Methods
- `get_onedrive_cache_path()` - Returns the path to the OneDrive cache directory
- `get_simulations_cache_path()` - Returns the path to the simulations cache directory

#### File Operations
- `download_file(sharing_link, filename)` - Downloads a file from OneDrive to cache
  - **Args**: `sharing_link` (OneDrive URL), `filename` (target filename)
  - **Returns**: Path to cached file or NULL on failure
  - **Note**: Provides real-time download progress through UI Messenger and StateStore

#### Simulation Cache Operations
- `cache_simulation(settings, mode, sim_state)` - Caches a simulation state
  - **Args**: `settings` (simulation settings), `mode` ("prerun" or "custom"), `sim_state` (state to cache)
  - **Returns**: TRUE if successful, FALSE otherwise
- `get_cached_simulation(settings, mode)` - Retrieves a simulation from cache
  - **Args**: `settings` (simulation settings), `mode` ("prerun" or "custom")
  - **Returns**: Simulation state or NULL if not found
- `is_simulation_cached(settings, mode)` - Checks if a simulation exists in cache
  - **Args**: `settings` (simulation settings), `mode` ("prerun" or "custom")
  - **Returns**: TRUE if found, FALSE otherwise

#### Space Management
- `cleanup(force, target_mb)` - Cleans up cache based on retention policy
  - **Args**: `force` (remove referenced files), `target_mb` (space to free)
  - **Returns**: TRUE if successful, FALSE otherwise
- `schedule_cleanup(interval_ms)` - Schedules periodic cleanup
  - **Args**: `interval_ms` (milliseconds between cleanups)
- `ensure_space_for(required_mb)` - Ensures space is available for a new file
  - **Args**: `required_mb` (size in MB)
  - **Returns**: TRUE if space available/freed, FALSE otherwise
- `get_stats()` - Returns cache statistics
  - **Returns**: List with cache statistics

### Private Methods

#### Registry Management
- `load_registry()` - Loads the registry from disk or initializes if not found
- `save_registry()` - Saves the registry to disk
- `add_to_registry(file_path, type, priority, references, metadata)` - Adds a file to the registry
- `update_registry_access(file_path)` - Updates access time for a file
- `update_registry_stats()` - Updates registry statistics

#### Dependency Tracking
- `find_simulation_dependencies(sim_state)` - Finds OneDrive files referenced by a simulation
- `get_referenced_files()` - Gets currently referenced files

#### Cache Operations
- `generate_simulation_key(settings, mode)` - Generates a cache key for a simulation
- `get_cache_size()` - Calculates total size of the cache

#### Memory Management
- `get_retention_times()` - Gets retention times adjusted for memory pressure
- `get_memory_info()` - Gets system memory information

## How It Works

### Cache Registry

The cache manager maintains a registry of all cached files with metadata:

```json
{
  "last_updated": "2023-01-01 12:00:00",
  "files": {
    "/path/to/file1.RData": {
      "type": "simulation",
      "size_kb": 1024,
      "created": "2023-01-01 10:00:00",
      "last_accessed": "2023-01-01 11:00:00",
      "priority": "normal",
      "references": ["/path/to/onedrive_file1.RData"],
      "metadata": {
        "version": "ehe",
        "location": "C.12580",
        "mode": "prerun"
      }
    }
  },
  "stats": {
    "total_size_kb": 1536,
    "simulation_count": 1,
    "onedrive_count": 1
  }
}
```

### Download Progress Tracking

The cache manager incorporates a dual approach for download progress tracking:

1. **StateStore Updates**: The download progress is tracked in the central StateStore, which maintains consistency with the application architecture
2. **Direct UI Messaging**: Real-time progress updates are sent directly to the UI via UIMessenger, bypassing the reactive system when the main thread is blocked
3. **Accurate Progress Calculation**: The system determines file size from HTTP Content-Length headers for precise progress tracking
4. **Robust Error Handling**: Failed downloads are properly tracked and reported through both channels

### Directory Structure

The cache manager creates and maintains these directories:

- `cache/` - Base cache directory
  - `onedrive/` - Cache for OneDrive files
  - `simulations/` - Cache for simulation results
  - `registry.json` - Registry file

### Intelligent Cleanup

The manager uses a tiered approach to cleanup:

1. **Age-Based Cleanup**: Files older than their retention time are removed
2. **Priority-Based Retention**: Files have priorities (critical, high, normal, low)
3. **Memory-Aware Retention**: Retention times are adjusted based on system memory pressure
4. **Reference Protection**: Referenced files are protected during normal cleanup

### Memory Monitoring

The system monitors memory usage and adjusts retention policies:

- **Normal** (<70% usage): Standard retention times
- **Moderate** (70-80% usage): 50% reduction in retention times
- **High** (80-90% usage): 75% reduction in retention times
- **Severe** (>90% usage): 90% reduction in retention times

## Usage

### Initialization

```r
# Initialize from app.R
cache_config <- get_component_config("caching")
cache_manager <- get_cache_manager()
```

### OneDrive File Operations

```r
# Download a file
file_path <- cache_manager$download_file(sharing_link, filename)
```

### Simulation Cache Operations

```r
# Cache a simulation
cache_manager$cache_simulation(settings, mode, sim_state)

# Check if simulation exists
exists <- cache_manager$is_simulation_cached(settings, mode)

# Get cached simulation
sim_state <- cache_manager$get_cached_simulation(settings, mode)
```

### Cleanup Operations

```r
# Run manual cleanup
cache_manager$cleanup()

# Ensure space for a new file
cache_manager$ensure_space_for(required_mb)
```

## Integration Points

- **OneDriveProvider**: Uses UnifiedCacheManager for downloading and caching files
- **StateStore**: Uses UnifiedCacheManager for simulation caching
- **app.R**: Initializes UnifiedCacheManager and schedules periodic cleanup
- **UIMessenger**: Receives download progress updates from UnifiedCacheManager for real-time UI updates

## Configuration

In `caching.yaml`:

```yaml
unified_cache:
  base_path: "cache"                # Base directory for all caches
  max_disk_usage_mb: 1500           # Maximum disk usage (1.5GB)
  memory_threshold_mb: 6000         # Memory threshold (6GB) 
  cleanup_interval_ms: 600000       # Cleanup every 10 minutes
  emergency_threshold_mb: 100       # Emergency cleanup when <100MB left
  retain_referenced: true           # Keep referenced files during normal cleanup
  retention_policy:                 # Retention times by priority
    critical: 86400                 # Critical files: 1 day (even under pressure)
    high: 43200                     # High priority: 12 hours
    normal: 7200                    # Normal: 2 hours
    low: 1800                       # Low priority: 30 minutes
```
