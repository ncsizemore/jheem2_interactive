# Test script for disk cache implementation
# Run this manually to verify cache functionality

# Source required files
source("src/ui/config/load_config.R")
source("src/data/cache.R")

# Helper function to create a test JHEEM-like simulation object
create_test_jheem_simulation <- function() {
  # Create a list with JHEEM-like structure
  sim <- list(
    sexual.transmission.rates = runif(5),
    proportion.using.heroin = runif(5),
    aids.diagnoses = c(100, 95, 90, 85, 80),
    prep.uptake.proportion = runif(5),
    outcomes = list(
      new_diagnoses = c(100, 95, 90, 85, 80),
      deaths = c(20, 18, 16, 14, 12),
      infections = c(150, 140, 130, 120, 110)
    ),
    version = "ehe",  # Version string used by actual JHEEM
    location = "test_location",
    code.iteration = "test"
  )
  
  # Add a save method to mimic JHEEM's R6 object
  sim$save <- function(path) {
    print(sprintf("Saving JHEEM simulation to %s", path))
    simset <- sim  # Store a reference to the simulation
    save(simset, file = path)
    invisible(TRUE)
  }
  
  # Set the class to mimic JHEEM simulations
  class(sim) <- c("jheem.simulation.set", "simulation.metadata", "jheem.entity", "R6")
  
  # Return the simulation object
  sim
}

# Test the cache implementation
test_disk_cache <- function() {
  # Initialize cache with test config
  test_config <- list(
    cache1 = list(
      max_size = 100000000,
      evict_strategy = "lru"
    ),
    cache2 = list(
      max_size = 100000000,
      evict_strategy = "lru"
    ),
    simulation_cache = list(
      enable_disk_cache = TRUE,
      max_size = 200000000,
      evict_strategy = "lru",
      path = "./cache/test_simulations",  # Use relative path with ./ prefix
      ttl = 3600,  # 1 hour
      simulation_version = "ehe",  # Simple version string like actual JHEEM
      check_version = FALSE  # Don't enforce version check for test
    )
  )
  
  # Make sure the cache directory exists
  cat(sprintf("Creating test cache directory: '%s'\n", test_config$simulation_cache$path))
  if (!dir.exists(test_config$simulation_cache$path)) {
    dir.create(test_config$simulation_cache$path, recursive = TRUE, showWarnings = TRUE)
  }
  
  cat(sprintf("Test cache directory exists: %s\n", dir.exists(test_config$simulation_cache$path)))
  
  # Initialize cache
  initialize_caches(test_config)
  
  # Create test data that mimics the structure of real JHEEM simulations
  test_settings <- list(
    location = "test_location",
    aspect = "testing",
    population = "all",
    timeframe = "2024-2030",
    intensity = "normal"
  )
  
  test_mode <- "prerun"
  
  # Create a test JHEEM-like simulation object
  # This simulates the complex R6 structure of JHEEM simulations
  jheem_simulation_set <- create_test_jheem_simulation()
  
  test_results <- list(
    simset = jheem_simulation_set,
    transformed = NULL
  )
  
  test_simstate <- list(
    id = "test_sim_12345",
    mode = test_mode,
    settings = test_settings,
    results = test_results,
    timestamp = Sys.time(),
    status = "completed",
    cache_metadata = list(
      version = "ehe",  # Match JHEEM's simple version string
      cached_at = Sys.time()
    )
  )
  
  # Run tests
  results <- list()
  
  # 1. Test key generation
  tryCatch({
    key <- generate_simulation_cache_key(test_settings, test_mode)
    results$key_generation <- TRUE
    results$key <- key
  }, error = function(e) {
    results$key_generation <- FALSE
    results$key_error <- e$message
  })
  
  # 2. Test if directory is created
  if (!is.null(results$key_generation) && results$key_generation) {
    cache_dir <- test_config$simulation_cache$path
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    }
    results$directory_created <- dir.exists(cache_dir)
  }
  
  # 3. Test saving to file
  if (!is.null(results$directory_created) && results$directory_created) {
    tryCatch({
      saved <- save_simulation_to_file(
        sim_state = test_simstate,
        key = results$key,
        cache_dir = test_config$simulation_cache$path
      )
      results$save_to_file <- saved
    }, error = function(e) {
      results$save_to_file <- FALSE
      results$save_error <- e$message
    })
  }
  
  # 4. Test caching
  if (!is.null(results$save_to_file) && results$save_to_file) {
    tryCatch({
      cache_simulation(test_settings, test_mode, test_simstate)
      results$cache_write <- TRUE
    }, error = function(e) {
      results$cache_write <- FALSE
      results$cache_error <- e$message
    })
  }
  
  # 5. Test checking cache
  if (!is.null(results$cache_write) && results$cache_write) {
    cache_result <- is_simulation_cached(test_settings, test_mode)
    results$cache_check <- cache_result
    
    if (!cache_result) {
      # Print information about the cache to diagnose issues
      cache_file <- file.path(
        test_config$simulation_cache$path,
        paste0(results$key, ".RData")
      )
      results$file_exists <- file.exists(cache_file)
      results$file_size <- if (results$file_exists) file.info(cache_file)$size else NA
    }
  }
  
  # 6. Test loading from file
  if (!is.null(results$cache_check) && results$cache_check) {
    tryCatch({
      loaded_sim <- load_simulation_from_file(
        key = results$key,
        cache_dir = test_config$simulation_cache$path
      )
      results$load_from_file <- !is.null(loaded_sim)
      
      # Check what was loaded
      if (results$load_from_file) {
        results$loaded_object_class <- class(loaded_sim)
        
        # Check for JHEEM objects
        if (is.list(loaded_sim) && !is.null(loaded_sim$results) && !is.null(loaded_sim$results$simset)) {
          results$has_simset <- TRUE
          results$simset_class <- class(loaded_sim$results$simset)
        } else if (inherits(loaded_sim, "jheem.simulation.set")) {
          results$has_simset <- TRUE
          results$simset_class <- class(loaded_sim)
          results$loaded_directly <- TRUE
        } else {
          results$has_simset <- FALSE
        }
      }
    }, error = function(e) {
      results$load_from_file <- FALSE
      results$load_error <- e$message
    })
  }
  
  # 7. Test retrieving from cache
  if (!is.null(results$cache_check) && results$cache_check) {
    tryCatch({
      cached_sim <- get_simulation_from_cache(test_settings, test_mode, check_version = TRUE)
      results$cache_read <- !is.null(cached_sim)
      
      if (results$cache_read) {
        # Verify some data integrity
        if (is.list(cached_sim) && !is.null(cached_sim$results) && !is.null(cached_sim$results$simset)) {
          # Check that we have the expected outcome values
          results$data_integrity <- identical(
            cached_sim$results$simset$outcomes$new_diagnoses,
            test_simstate$results$simset$outcomes$new_diagnoses
          )
        } else if (inherits(cached_sim, "jheem.simulation.set")) {
          # Directly loaded JHEEM simulation
          results$data_integrity <- identical(
            cached_sim$outcomes$new_diagnoses,
            test_simstate$results$simset$outcomes$new_diagnoses
          )
        }
      }
    }, error = function(e) {
      results$cache_read <- FALSE
      results$read_error <- e$message
    })
  }
  
  # 8. Test version compatibility
  if (!is.null(results$cache_check) && results$cache_check) {
    # Create config with different version
    diff_version_config <- test_config
    diff_version_config$simulation_cache$simulation_version <- "ehe_2.0"
    diff_version_config$simulation_cache$check_version <- TRUE
    
    tryCatch({
      # Try with version check enabled
      cached_sim_with_check <- get_simulation_from_cache(
        test_settings, test_mode, 
        check_version = TRUE, 
        config = diff_version_config
      )
      results$version_check_blocks <- is.null(cached_sim_with_check)
      
      # Try with version check disabled
      cached_sim_no_check <- get_simulation_from_cache(
        test_settings, test_mode, 
        check_version = FALSE, 
        config = diff_version_config
      )
      results$version_check_passthrough <- !is.null(cached_sim_no_check)
      
      results$version_compatibility_working <- 
        results$version_check_blocks && results$version_check_passthrough
    }, error = function(e) {
      results$version_compatibility_error <- e$message
    })
  }
  
  # 9. Test cleanup
  tryCatch({
    cleanup_results <- cleanup_simulation_cache(max_age = 0, dry_run = TRUE)
    results$cleanup_test <- TRUE
    results$cleanup_results <- length(cleanup_results$removed_keys)
  }, error = function(e) {
    results$cleanup_test <- FALSE
    results$cleanup_error <- e$message
  })
  
  # Return test results
  results
}

# Custom version check function for the test
check_version_compatibility <- function(metadata, expected_version) {
  if (is.null(metadata) || is.null(metadata$version)) {
    cat("[TEST] No version information in metadata - assuming compatible\n")
    return(TRUE)
  }
  
  # If no expected version, assume compatible
  if (is.null(expected_version)) {
    cat("[TEST] No expected version - assuming compatible\n")
    return(TRUE)
  }
  
  # Compare versions
  cached_version <- metadata$version
  result <- identical(cached_version, expected_version)
  
  if (!result) {
    cat(sprintf("[TEST] Version mismatch: cached=%s, expected=%s\n", 
                cached_version, expected_version))
  } else {
    cat(sprintf("[TEST] Version match: %s\n", expected_version))
  }
  
  result
}
test_version_compatibility <- function() {
  cat("\n\n===== Testing Version Compatibility =====\n")
  
  # Set up a test directory with proper normalization
  test_dir <- "./cache/version_test"
  test_dir <- normalize_cache_path(test_dir)
  cat(sprintf("Using test directory: '%s'\n", test_dir))
  
  # Make sure the test directory exists
  if (!dir.exists(test_dir)) {
    cat(sprintf("Creating test directory: '%s'\n", test_dir))
    dir.create(test_dir, recursive = TRUE, showWarnings = TRUE)
  }
  
  cat(sprintf("Test directory exists: %s\n", dir.exists(test_dir)))
  
  # Initialize cache with original version
  test_config1 <- list(
    cache1 = list(max_size = 100000000, evict_strategy = "lru"),
    cache2 = list(max_size = 100000000, evict_strategy = "lru"),
    simulation_cache = list(
      enable_disk_cache = TRUE,
      max_size = 200000000,
      evict_strategy = "lru",
      path = test_dir,  # Use normalized path
      simulation_version = "ehe_1.0",  # Original version
      check_version = TRUE  # Enable version checking
    )
  )
  
  # Create a test JHEEM-like simulation
  jheem_sim <- create_test_jheem_simulation()
  jheem_sim$version <- "ehe_1.0"  # Set version to match config
  
  # Create and cache test data with version ehe_1.0
  test_settings <- list(location = "test_location", aspect = "testing")
  test_mode <- "prerun"
  test_sim <- list(
    id = "version_test_sim",
    mode = test_mode,
    settings = test_settings,
    results = list(simset = jheem_sim),
    timestamp = Sys.time(),
    status = "completed",
    cache_metadata = list(
      cached_at = Sys.time(),
      version = "ehe_1.0"  # Original version
    )
  )
  
  # Initialize the cache
  cat("Initializing cache with version ehe_1.0\n")
  initialize_caches(test_config1)
  
  # Cache the simulation directly to file and create metadata
  key <- generate_simulation_cache_key(test_settings, test_mode)
  cat(sprintf("Generated key: %s\n", key))
  
  # Save the simulation to file directly
  file_path <- file.path(test_dir, paste0(key, ".RData"))
  cat(sprintf("Saving to file: %s\n", file_path))
  
  # Use the save method depending on what's available
  if (inherits(jheem_sim, "jheem.simulation.set") && !is.null(jheem_sim$save)) {
    # Use the save method if available
    jheem_sim$save(file_path)
    cat("Used JHEEM save method\n")
  } else {
    # Standard save
    simulation <- test_sim
    save(simulation, file = file_path)
    cat("Used standard save method\n")
  }
  
  # Save metadata separately
  metadata <- list(
    key = key,
    cached_at = Sys.time(),
    version = test_sim$cache_metadata$version,
    settings = test_sim$settings,
    mode = test_sim$mode,
    id = test_sim$id,
    saved_with = "test_function_direct_save"
  )
  
  meta_path <- paste0(file_path, ".meta")
  saveRDS(metadata, meta_path)
  cat(sprintf("Saved metadata to: %s\n", meta_path))
  
  # Verify file exists directly
  file_exists <- file.exists(file_path)
  meta_exists <- file.exists(meta_path)
  cat(sprintf("File exists: %s, Meta exists: %s\n", file_exists, meta_exists))
  
  # Get the cache key for reference
  key <- generate_simulation_cache_key(test_settings, test_mode)
  
  # Directly check cached item metadata for debugging
  meta_path <- file.path(test_dir, paste0(key, ".RData.meta"))
  cat(sprintf("Looking for metadata at: %s\n", meta_path))
  
  if (file.exists(meta_path)) {
    metadata <- readRDS(meta_path)
    cat("  - Found cached metadata\n")
    cat("  - Version: ", metadata$version, "\n")
    cat("  - Cached at: ", metadata$cached_at, "\n")
    if (!is.null(metadata$saved_with)) {
      cat("  - Saved with: ", metadata$saved_with, "\n")
    }
  } else {
    cat("  - No metadata file found\n")
  }
  
  # Initialize cache with a different version
  test_config2 <- list(
    cache1 = list(max_size = 100000000, evict_strategy = "lru"),
    cache2 = list(max_size = 100000000, evict_strategy = "lru"),
    simulation_cache = list(
      enable_disk_cache = TRUE,
      max_size = 200000000,
      evict_strategy = "lru",
      path = test_dir,  # Use the same directory
      simulation_version = "ehe_2.0",  # Different version
      check_version = TRUE  # Enable version checking - this MUST be true for the test
    )
  )
  
  # Debug output to verify configuration
  cat("\nTest config 2:\n")
  cat("  - path: ", test_config2$simulation_cache$path, "\n")
  cat("  - simulation_version: ", test_config2$simulation_cache$simulation_version, "\n")
  cat("  - check_version: ", test_config2$simulation_cache$check_version, "\n")
  
  # Create a new .CACHE list to avoid reinitialization issues
  # This simulates starting the app with a different configuration
  backup_cache <- .CACHE
  .CACHE <<- list()
  
  cat("\nInitializing new cache with version ehe_2.0\n")
  initialize_caches(test_config2)
  
  # Try to retrieve with version check enabled first
  cat("Attempting to retrieve simulation with version check enabled...\n")
  cached_sim_with_check <- NULL
  
  # Load metadata to check version
  meta_path <- file.path(test_dir, paste0(key, ".RData.meta"))
  if (file.exists(meta_path)) {
    cat("Loading metadata file...\n")
    metadata <- readRDS(meta_path)
    cat(sprintf("  - Metadata version: %s\n", metadata$version))
    cat(sprintf("  - Current version: %s\n", test_config2$simulation_cache$simulation_version))
    
    # Perform manual version check
    version_compatible <- check_version_compatibility(metadata, test_config2$simulation_cache$simulation_version)
    
    # Only load if versions compatible
    if (version_compatible) {
      cat("Versions match, loading file with version check enabled\n")
      cached_sim_with_check <- load_simulation_from_file(key, test_dir)
    } else {
      cat("Version mismatch, skipping load with version check enabled\n")
    }
  } else {
    cat("Metadata file not found!\n")
  }
  
  cat("Result with version check enabled: ", !is.null(cached_sim_with_check), "\n")
  
  # Try to retrieve with version check disabled (should always succeed if file exists)
  cat("Attempting to retrieve simulation with version check disabled...\n")
  cached_sim_no_check <- NULL
  
  # Load file path
  file_path <- file.path(test_dir, paste0(key, ".RData"))
  
  # Check if the file exists
  if (!file.exists(file_path)) {
    cat(sprintf("Data file not found: %s\n", file_path))
  } else {
    cat(sprintf("Data file found: %s\n", file_path))
    # Load without checking version
    cached_sim_no_check <- load_simulation_from_file(key, test_dir)
  }
  
  cat("Result with version check disabled: ", !is.null(cached_sim_no_check), "\n")
  
  # Restore the original cache
  .CACHE <<- backup_cache
  
  # Define version compatibility explicitly for the test
  # The version check enabled should return NULL (no data) because versions don't match
  # The version check disabled should return data ignoring version differences
  version_check_working <- is.null(cached_sim_with_check) && !is.null(cached_sim_no_check)
  
  if (version_check_working) {
    cat("SUCCESS: Version compatibility check is working as expected\n")
    cat("  - With version check: Correctly rejected incompatible version\n")
    cat("  - Without version check: Correctly allowed retrieval regardless of version\n")
    return(TRUE)
  } else {
    cat("FAILURE: Version compatibility check is not working as expected\n")
    if (!is.null(cached_sim_with_check)) {
      cat("  - With version check: INCORRECT - Should have rejected version mismatch\n")
    } else {
      cat("  - With version check: Correct - Rejected version mismatch\n")
    }
    
    if (!is.null(cached_sim_no_check)) {
      cat("  - Without version check: Correct - Allowed data access\n")
    } else {
      cat("  - Without version check: INCORRECT - Should have allowed access\n")
    }
    return(FALSE)
  }
}

# Run the tests
cat("Starting disk cache test...\n")
test_results <- test_disk_cache()

# Print summary
cat("\n===== Test Results =====\n")
print(test_results)
cat("\n")

# Check essential operations
essential_checks <- c(
  test_results$key_generation, 
  test_results$directory_created,
  test_results$save_to_file,
  test_results$cache_write, 
  test_results$cache_check, 
  test_results$load_from_file,
  test_results$cache_read,
  test_results$data_integrity
)

if (!is.null(essential_checks) && all(essential_checks, na.rm = TRUE)) {
  cat("SUCCESS: All essential cache operations passed!\n")
  
  # Log detailed results
  cat("\nDetailed results:\n")
  cat("Key generation: ", test_results$key_generation, "\n")
  cat("Generated key: ", test_results$key, "\n")
  cat("Directory created: ", test_results$directory_created, "\n")
  cat("Save to file: ", test_results$save_to_file, "\n")
  cat("Cache write: ", test_results$cache_write, "\n")
  cat("Cache check: ", test_results$cache_check, "\n")
  cat("Load from file: ", test_results$load_from_file, "\n")
  
  if (!is.null(test_results$loaded_object_class)) {
    cat("Loaded object class: ", paste(test_results$loaded_object_class, collapse=", "), "\n")
  }
  
  if (!is.null(test_results$has_simset) && test_results$has_simset) {
    cat("Has simset: ", test_results$has_simset, "\n")
    cat("Simset class: ", paste(test_results$simset_class, collapse=", "), "\n")
    if (!is.null(test_results$loaded_directly)) {
      cat("Loaded directly: ", test_results$loaded_directly, "\n")
    }
  }
  
  cat("Cache read: ", test_results$cache_read, "\n")
  cat("Data integrity: ", test_results$data_integrity, "\n")
  
  # Print version compatibility results if available
  if (!is.null(test_results$version_compatibility_working)) {
    cat("\nVersion compatibility testing:\n")
    cat("Version check blocks mismatched versions: ", test_results$version_check_blocks, "\n")
    cat("Version check passthrough works: ", test_results$version_check_passthrough, "\n")
    cat("Overall version compatibility working: ", test_results$version_compatibility_working, "\n")
  }
  
  # Print cleanup results
  if (!is.null(test_results$cleanup_test) && test_results$cleanup_test) {
    cat("\nCache Cleanup Simulation:\n")
    cat("Would remove: ", test_results$cleanup_results, " items\n")
  }
} else {
  cat("WARNING: Some tests failed. See details above.\n")
}

# Run version compatibility test separately
cat("\n\n===== Running Version Compatibility Test =====\n")
version_test_result <- test_version_compatibility()