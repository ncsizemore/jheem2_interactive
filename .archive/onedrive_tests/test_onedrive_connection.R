# Test OneDrive connection using Microsoft365R package
# This script tests if we can connect to OneDrive and perform basic operations

# Install packages if not already installed
if (!requireNamespace("Microsoft365R", quietly = TRUE)) {
  install.packages("Microsoft365R")
}

library(Microsoft365R)

# Function to test OneDrive connection
test_onedrive_connection <- function() {
  cat("Testing OneDrive connection...\n")
  
  tryCatch({
    # Attempt to connect to business OneDrive
    # This will open a browser window for authentication
    cat("Connecting to business OneDrive...\n")
    od <- get_business_onedrive()
    
    # List files in root directory
    cat("Listing files in root directory...\n")
    files <- od$list_files()
    cat(sprintf("Successfully connected to OneDrive. Found %d items in root folder.\n", length(files)))
    
    # Create a test folder
    folder_name <- paste0("test_folder_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    cat(sprintf("Creating test folder '%s'...\n", folder_name))
    folder <- od$create_folder(folder_name)
    cat("Test folder created successfully.\n")
    
    # Create a small test file
    test_file_path <- tempfile(fileext = ".txt")
    cat("Test content from JHEEM OneDrive integration", file = test_file_path)
    
    # Upload test file
    cat("Uploading test file...\n")
    file_item <- folder$upload_file(test_file_path)
    cat(sprintf("Test file uploaded successfully with name: %s\n", file_item$name))
    
    # Download the file
    download_path <- tempfile(fileext = ".txt")
    cat(sprintf("Downloading test file to: %s\n", download_path))
    file_item$download(download_path)
    cat("File downloaded successfully.\n")
    
    # Verify content
    content <- readLines(download_path)
    cat(sprintf("File content: '%s'\n", content))
    
    # Clean up: delete test folder
    cat("Cleaning up: deleting test folder...\n")
    folder$delete()
    cat("Test folder deleted successfully.\n")
    
    cat("\nAll tests PASSED! OneDrive connection is working properly.\n")
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("\nERROR: %s\n", e$message))
    cat("OneDrive connection test FAILED.\n")
    return(FALSE)
  })
}

# Run the test
test_onedrive_connection()
