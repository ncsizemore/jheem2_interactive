# Test OneDrive access using WebDAV protocol
# This script tests if we can access OneDrive via WebDAV without API restrictions

library(httr)
library(xml2)
library(stringr)

# ========== Helper Functions ==========

# Parse WebDAV response XML
parse_webdav_response <- function(response) {
  if (status_code(response) >= 400) {
    cat(sprintf("Error: HTTP status %d\n", status_code(response)))
    cat(content(response, "text"), "\n")
    return(NULL)
  }
  
  # Parse XML response
  xml_content <- content(response, "text", encoding = "UTF-8")
  
  # Some WebDAV responses may not be valid XML
  tryCatch({
    xml_doc <- read_xml(xml_content)
    return(xml_doc)
  }, error = function(e) {
    cat(sprintf("Warning: Could not parse XML response: %s\n", e$message))
    cat("Response content:\n")
    cat(substr(xml_content, 1, 500), "...\n")
    return(NULL)
  })
}

# Extract file information from WebDAV response
extract_file_info <- function(xml_doc) {
  if (is.null(xml_doc)) {
    return(NULL)
  }
  
  # Get all response elements
  responses <- xml_find_all(xml_doc, "//d:response", ns = c(d = "DAV:"))
  
  # Extract information for each file/folder
  result <- list()
  for (response in responses) {
    # Get href (path)
    href <- xml_text(xml_find_first(response, ".//d:href", ns = c(d = "DAV:")))
    
    # Get properties
    props <- xml_find_first(response, ".//d:prop", ns = c(d = "DAV:"))
    
    # Check if it's a collection (folder)
    is_collection <- !is.na(xml_find_first(props, ".//d:resourcetype/d:collection", ns = c(d = "DAV:")))
    
    # Get last modified time
    last_modified <- xml_text(xml_find_first(props, ".//d:getlastmodified", ns = c(d = "DAV:")))
    
    # Get size
    size <- xml_text(xml_find_first(props, ".//d:getcontentlength", ns = c(d = "DAV:")))
    
    # Get content type
    content_type <- xml_text(xml_find_first(props, ".//d:getcontenttype", ns = c(d = "DAV:")))
    
    # Add to result
    result[[length(result) + 1]] <- list(
      href = href,
      path = basename(href),
      is_folder = is_collection,
      last_modified = last_modified,
      size = as.numeric(size),
      content_type = content_type
    )
  }
  
  return(result)
}

# ========== Test Functions ==========

# Test WebDAV connection to OneDrive
test_webdav_connection <- function(username, password, retry_with_encoded = TRUE) {
  cat("\n===== Testing WebDAV Connection =====\n")
  
  # Try to determine the CID for WebDAV URL
  cid <- NULL
  
  # Try with Business OneDrive first
  business_url <- "https://jhu-my.sharepoint.com/personal/"
  
  # Extract username part (before @)
  username_part <- sub("@.*$", "", username)
  
  # Clean up username part for URL (remove special chars)
  clean_username <- str_replace_all(username_part, "[^a-zA-Z0-9]", "")
  
  # Try to construct business WebDAV URL
  business_webdav_url <- sprintf("%s%s_jhu_edu/Documents", business_url, clean_username)
  
  cat(sprintf("Trying Business OneDrive WebDAV URL: %s\n", business_webdav_url))
  
  # Test connection with PROPFIND request (list files)
  business_response <- tryCatch({
    PROPFIND(
      url = business_webdav_url,
      authenticate(username, password, type = "basic"),
      add_headers(Depth = "1"),
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error connecting to business WebDAV: %s\n", e$message))
    return(NULL)
  })
  
  if (!is.null(business_response) && status_code(business_response) < 400) {
    cat("✓ Successfully connected to Business OneDrive via WebDAV!\n")
    cat(sprintf("Status code: %d\n", status_code(business_response)))
    
    # If successful, parse and return the response
    xml_doc <- parse_webdav_response(business_response)
    file_list <- extract_file_info(xml_doc)
    
    return(list(
      success = TRUE,
      url = business_webdav_url,
      files = file_list
    ))
  }
  
  # If business OneDrive failed, try personal OneDrive
  cat("Business OneDrive connection failed or returned error.\n")
  cat("This is expected if you're using a personal OneDrive account.\n")
  
  cat("\nTrying to find personal OneDrive CID...\n")
  cat("Note: This might be difficult without interactive login.\n")
  
  # Try with standard d.docs.live.net URL
  # This requires the CID which we don't have directly
  # Could try with a default Documents path
  personal_webdav_url <- "https://d.docs.live.net/Documents"
  
  cat(sprintf("Trying Personal OneDrive WebDAV URL: %s\n", personal_webdav_url))
  
  # Test connection with PROPFIND request (list files)
  personal_response <- tryCatch({
    PROPFIND(
      url = personal_webdav_url,
      authenticate(username, password, type = "basic"),
      add_headers(Depth = "1"),
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error connecting to personal WebDAV: %s\n", e$message))
    return(NULL)
  })
  
  if (!is.null(personal_response) && status_code(personal_response) < 400) {
    cat("✓ Successfully connected to Personal OneDrive via WebDAV!\n")
    cat(sprintf("Status code: %d\n", status_code(personal_response)))
    
    # If successful, parse and return the response
    xml_doc <- parse_webdav_response(personal_response)
    file_list <- extract_file_info(xml_doc)
    
    return(list(
      success = TRUE,
      url = personal_webdav_url,
      files = file_list
    ))
  }
  
  # If using standard password authentication fails, try with URL-encoded credentials
  if (retry_with_encoded && !is.null(password)) {
    cat("\nTrying with URL-encoded credentials...\n")
    
    # URL-encode the password for special characters
    encoded_password <- URLencode(password, reserved = TRUE)
    
    # Try again with encoded password
    return(test_webdav_connection(username, encoded_password, retry_with_encoded = FALSE))
  }
  
  # If all attempts fail
  cat("✗ All WebDAV connection attempts failed.\n")
  cat("This could be due to:\n")
  cat("1. Incorrect username/password\n")
  cat("2. WebDAV access being disabled for your account\n")
  cat("3. Additional authentication factors required\n")
  
  return(list(
    success = FALSE,
    message = "Could not connect to OneDrive via WebDAV"
  ))
}

# Test file operations via WebDAV
test_webdav_file_operations <- function(webdav_url, username, password) {
  cat("\n===== Testing WebDAV File Operations =====\n")
  
  if (is.null(webdav_url) || webdav_url == "") {
    cat("No WebDAV URL provided. Skipping file operations test.\n")
    return(list(success = FALSE, message = "No WebDAV URL provided"))
  }
  
  # Create test folder name
  test_folder_name <- paste0("jheem_test_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  test_folder_url <- paste0(webdav_url, "/", test_folder_name)
  
  cat(sprintf("Creating test folder: %s\n", test_folder_name))
  
  # 1. Create folder
  folder_response <- tryCatch({
    MKCOL(
      url = test_folder_url,
      authenticate(username, password, type = "basic"),
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error creating folder: %s\n", e$message))
    return(NULL)
  })
  
  if (is.null(folder_response) || status_code(folder_response) >= 400) {
    cat(sprintf("✗ Failed to create test folder. Status: %s\n", 
                ifelse(is.null(folder_response), "Error", status_code(folder_response))))
    return(list(success = FALSE, message = "Failed to create folder"))
  }
  
  cat(sprintf("✓ Successfully created folder: %s\n", test_folder_name))
  
  # 2. Create a test file
  test_file_name <- paste0("test_file_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
  test_file_content <- paste0("Test content created at ", Sys.time(), 
                             " for JHEEM WebDAV integration test")
  test_file_url <- paste0(test_folder_url, "/", test_file_name)
  
  cat(sprintf("Uploading test file: %s\n", test_file_name))
  
  file_response <- tryCatch({
    PUT(
      url = test_file_url,
      authenticate(username, password, type = "basic"),
      body = test_file_content,
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error uploading file: %s\n", e$message))
    return(NULL)
  })
  
  if (is.null(file_response) || status_code(file_response) >= 400) {
    cat(sprintf("✗ Failed to upload test file. Status: %s\n", 
                ifelse(is.null(file_response), "Error", status_code(file_response))))
    
    # Try to clean up the folder we created
    tryCatch({
      DELETE(
        url = test_folder_url,
        authenticate(username, password, type = "basic")
      )
    }, error = function(e) {})
    
    return(list(success = FALSE, message = "Failed to upload file"))
  }
  
  cat(sprintf("✓ Successfully uploaded file: %s\n", test_file_name))
  
  # 3. Download the file to verify
  cat("Downloading file to verify content...\n")
  
  download_response <- tryCatch({
    GET(
      url = test_file_url,
      authenticate(username, password, type = "basic"),
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error downloading file: %s\n", e$message))
    return(NULL)
  })
  
  if (is.null(download_response) || status_code(download_response) >= 400) {
    cat(sprintf("✗ Failed to download test file. Status: %s\n", 
                ifelse(is.null(download_response), "Error", status_code(download_response))))
  } else {
    # Check content
    downloaded_content <- content(download_response, "text", encoding = "UTF-8")
    
    if (identical(downloaded_content, test_file_content)) {
      cat("✓ Downloaded content matches original\n")
    } else {
      cat("✗ Downloaded content does not match original\n")
      cat("Original: ", test_file_content, "\n")
      cat("Downloaded: ", downloaded_content, "\n")
    }
  }
  
  # 4. Delete the file
  cat("Deleting test file...\n")
  
  delete_file_response <- tryCatch({
    DELETE(
      url = test_file_url,
      authenticate(username, password, type = "basic"),
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error deleting file: %s\n", e$message))
    return(NULL)
  })
  
  if (is.null(delete_file_response) || status_code(delete_file_response) >= 400) {
    cat(sprintf("✗ Failed to delete test file. Status: %s\n", 
                ifelse(is.null(delete_file_response), "Error", status_code(delete_file_response))))
  } else {
    cat("✓ Successfully deleted test file\n")
  }
  
  # 5. Delete the folder
  cat("Deleting test folder...\n")
  
  delete_folder_response <- tryCatch({
    DELETE(
      url = test_folder_url,
      authenticate(username, password, type = "basic"),
      verbose()
    )
  }, error = function(e) {
    cat(sprintf("Error deleting folder: %s\n", e$message))
    return(NULL)
  })
  
  if (is.null(delete_folder_response) || status_code(delete_folder_response) >= 400) {
    cat(sprintf("✗ Failed to delete test folder. Status: %s\n", 
                ifelse(is.null(delete_folder_response), "Error", status_code(delete_folder_response))))
    return(list(success = FALSE, message = "Failed to clean up test folder"))
  } else {
    cat("✓ Successfully deleted test folder\n")
  }
  
  cat("\n✓✓✓ WebDAV file operations test completed successfully!\n")
  return(list(success = TRUE))
}

# ========== Main Test Script ==========

# Get credentials
cat("This script tests OneDrive access via WebDAV protocol\n")
cat("Please enter your OneDrive credentials:\n")

cat("Enter your email address: ")
username <- readline(prompt = "")

cat("Enter your password: ")
password <- readline(prompt = "")

# Run connection test
result <- test_webdav_connection(username, password)

# If connection successful, test file operations
if (result$success) {
  cat("\nConnection successful!\n")
  
  if (!is.null(result$files)) {
    cat("\nFiles in root folder:\n")
    for (file in result$files) {
      cat(sprintf("- %s (%s, %s bytes)\n", 
                  file$path, 
                  ifelse(file$is_folder, "Folder", "File"), 
                  ifelse(is.na(file$size), "N/A", file$size)))
    }
  }
  
  # Ask if user wants to test file operations
  cat("\nWould you like to test file operations? (y/n): ")
  test_ops <- readline(prompt = "")
  
  if (tolower(test_ops) == "y") {
    file_ops_result <- test_webdav_file_operations(result$url, username, password)
    
    if (file_ops_result$success) {
      cat("\nWebDAV integration tests passed successfully!\n")
      cat("This confirms that WebDAV can be used for both pre-run simulations and caching.\n")
    } else {
      cat("\nFile operations test failed. WebDAV access may be read-only.\n")
      cat("This suggests WebDAV could be used for pre-run simulations but not for caching.\n")
    }
  }
} else {
  cat("\nWebDAV connection failed. This approach may not be viable for your OneDrive account.\n")
  cat("Consider exploring other options like sharing links or alternative storage services.\n")
}
