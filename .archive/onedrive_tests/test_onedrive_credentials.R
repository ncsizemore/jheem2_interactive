# Test the OneDrive Provider with application credentials
# This script tests the functionality of the OneDrive provider implementation

source("src/data/providers/onedrive_provider.R")

# ========== Test Configuration ==========

# Function to prompt for credentials if not provided
get_credentials <- function() {
  client_id <- Sys.getenv("ONEDRIVE_CLIENT_ID")
  client_secret <- Sys.getenv("ONEDRIVE_CLIENT_SECRET")
  tenant_id <- Sys.getenv("ONEDRIVE_TENANT_ID")
  
  # Prompt for credentials if not found in environment
  if (nchar(client_id) < 10) {
    cat("Enter your OneDrive Client ID: ")
    client_id <- readline(prompt = "")
  }
  
  if (nchar(client_secret) < 5) {
    cat("Enter your OneDrive Client Secret: ")
    client_secret <- readline(prompt = "")
  }
  
  if (nchar(tenant_id) < 10) {
    cat("Enter your OneDrive Tenant ID: ")
    tenant_id <- readline(prompt = "")
  }
  
  # Return as a list
  list(
    client_id = client_id,
    client_secret = client_secret,
    tenant_id = tenant_id
  )
}

# ========== Test Functions ==========

# Test provider initialization
test_provider_init <- function(credentials) {
  cat("\n===== Testing Provider Initialization =====\n")
  
  # Create config
  config <- list(
    client_id = credentials$client_id,
    client_secret = credentials$client_secret,
    tenant_id = credentials$tenant_id,
    folder = "jheem-test",
    max_size = 1000000000,  # 1GB
    evict_strategy = "lru"
  )
  
  # Initialize provider
  tryCatch({
    provider <- initialize_onedrive_provider(config)
    cat("Provider initialized successfully\n")
    
    # Test if we got a valid token
    if (!is.null(provider$token)) {
      cat("✓ Access token obtained successfully\n")
    } else {
      cat("✗ Failed to obtain access token\n")
    }
    
    return(provider)
  }, error = function(e) {
    cat(sprintf("✗ Provider initialization failed: %s\n", e$message))
    return(NULL)
  })
}

# Test file operations
test_file_operations <- function(provider) {
  cat("\n===== Testing File Operations =====\n")
  
  if (is.null(provider)) {
    cat("Skipping file operations tests - provider is NULL\n")
    return(FALSE)
  }
  
  # Create a test file
  test_file_path <- tempfile(fileext = ".txt")
  cat(sprintf("Test content created at %s", Sys.time()), file = test_file_path)
  cat(sprintf("Created test file at %s\n", test_file_path))
  
  # Generate a unique remote path
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  remote_path <- sprintf("test_file_%s.txt", timestamp)
  
  # Test file upload
  cat("Testing file upload...\n")
  upload_result <- provider$save_file(test_file_path, remote_path)
  
  if (upload_result) {
    cat(sprintf("✓ File upload successful: %s\n", remote_path))
  } else {
    cat(sprintf("✗ File upload failed: %s\n", remote_path))
    return(FALSE)
  }
  
  # Test file existence
  cat("Testing file existence check...\n")
  exists_result <- provider$file_exists(remote_path)
  
  if (exists_result) {
    cat(sprintf("✓ File exists check successful: %s\n", remote_path))
  } else {
    cat(sprintf("✗ File exists check failed: %s\n", remote_path))
    return(FALSE)
  }
  
  # Test file download
  cat("Testing file download...\n")
  download_path <- tempfile(fileext = ".txt")
  download_result <- provider$get_file(remote_path, download_path)
  
  if (download_result && file.exists(download_path)) {
    cat(sprintf("✓ File download successful: %s\n", download_path))
    
    # Verify content
    original_content <- readLines(test_file_path)
    downloaded_content <- readLines(download_path)
    
    if (identical(original_content, downloaded_content)) {
      cat("✓ Downloaded content matches original\n")
    } else {
      cat("✗ Downloaded content does not match original\n")
    }
  } else {
    cat(sprintf("✗ File download failed: %s\n", download_path))
    return(FALSE)
  }
  
  # Test file deletion
  cat("Testing file deletion...\n")
  delete_result <- provider$delete_file(remote_path)
  
  if (delete_result) {
    cat(sprintf("✓ File deletion successful: %s\n", remote_path))
  } else {
    cat(sprintf("✗ File deletion failed: %s\n", remote_path))
    return(FALSE)
  }
  
  # Verify file no longer exists
  cat("Verifying file no longer exists...\n")
  exists_after_delete <- provider$file_exists(remote_path)
  
  if (!exists_after_delete) {
    cat(sprintf("✓ File correctly shows as not existing after deletion: %s\n", remote_path))
  } else {
    cat(sprintf("✗ File still shows as existing after deletion: %s\n", remote_path))
    return(FALSE)
  }
  
  # Clean up
  if (file.exists(test_file_path)) {
    file.remove(test_file_path)
  }
  if (file.exists(download_path)) {
    file.remove(download_path)
  }
  
  cat("File operations tests passed successfully\n")
  return(TRUE)
}

# Test cache operations
test_cache_operations <- function(credentials) {
  cat("\n===== Testing Cache Operations =====\n")
  
  # Create config
  config <- list(
    client_id = credentials$client_id,
    client_secret = credentials$client_secret,
    tenant_id = credentials$tenant_id,
    folder = "jheem-cache",
    max_size = 1000000000,  # 1GB
    evict_strategy = "lru"
  )
  
  # Create OneDrive cache
  tryCatch({
    cache <- create_onedrive_cache(config)
    cat("OneDrive cache created successfully\n")
    
    # Test cache operations
    test_key <- paste0("test_key_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    test_value <- list(name = "Test Value", timestamp = Sys.time())
    
    # Test set
    cat(sprintf("Testing cache set operation for key: %s\n", test_key))
    cache$set(test_key, test_value)
    
    # Test get
    cat(sprintf("Testing cache get operation for key: %s\n", test_key))
    retrieved_value <- cache$get(test_key)
    
    if (!is.null(retrieved_value) && identical(retrieved_value$name, test_value$name)) {
      cat("✓ Cache get operation successful\n")
    } else {
      cat("✗ Cache get operation failed\n")
      return(FALSE)
    }
    
    # Test exists
    cat(sprintf("Testing cache exists operation for key: %s\n", test_key))
    exists_result <- cache$exists(test_key)
    
    if (exists_result) {
      cat("✓ Cache exists operation successful\n")
    } else {
      cat("✗ Cache exists operation failed\n")
      return(FALSE)
    }
    
    # Test remove
    cat(sprintf("Testing cache remove operation for key: %s\n", test_key))
    cache$remove(test_key)
    
    # Verify removal
    exists_after_remove <- cache$exists(test_key)
    if (!exists_after_remove) {
      cat("✓ Cache remove operation successful\n")
    } else {
      cat("✗ Cache remove operation failed\n")
      return(FALSE)
    }
    
    cat("Cache operations tests passed successfully\n")
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("✗ Cache operations failed: %s\n", e$message))
    return(FALSE)
  })
}

# ========== Main Test Script ==========

# Get credentials
credentials <- get_credentials()

# Run tests
cat("\n===== Starting OneDrive Provider Tests =====\n")

# Test provider initialization
provider <- test_provider_init(credentials)

# Test file operations
file_ops_result <- test_file_operations(provider)

# Test cache operations
cache_ops_result <- test_cache_operations(credentials)

# Show overall results
cat("\n===== Test Results Summary =====\n")
cat(sprintf("Provider Initialization: %s\n", if(!is.null(provider)) "Passed" else "Failed"))
cat(sprintf("File Operations Tests: %s\n", if(file_ops_result) "Passed" else "Failed"))
cat(sprintf("Cache Operations Tests: %s\n", if(cache_ops_result) "Passed" else "Failed"))

if (!is.null(provider) && file_ops_result && cache_ops_result) {
  cat("\n✓✓✓ All tests passed successfully! The OneDrive provider is working correctly.\n")
  cat("You can now use this provider for both pre-run simulations and caching.\n")
} else {
  cat("\n✗✗✗ Some tests failed. Please check the output above for details.\n")
  cat("Try to resolve any authentication or permission issues before proceeding.\n")
}
