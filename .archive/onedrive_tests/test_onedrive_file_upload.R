# Test OneDrive file upload to a shared folder
# This script tests if we can upload files to a shared folder using its sharing link

library(httr2)
library(jsonlite)

# ========== Helper Functions ==========

# Extract sharing token from a OneDrive sharing URL
extract_sharing_token <- function(sharing_url) {
  # Various patterns of OneDrive sharing URLs
  if (grepl("1drv.ms", sharing_url)) {
    # Short link format
    return(sharing_url)  # Just use the whole short URL
  } else if (grepl("sharepoint.com", sharing_url)) {
    # SharePoint format
    matches <- regmatches(sharing_url, regexpr("[a-zA-Z0-9!_-]{43}(?:\\?[^&]*)?", sharing_url))
    if (length(matches) > 0) {
      return(matches[1])
    }
  } else if (grepl("[uU]!|[sS]!", sharing_url)) {
    # Standard OneDrive format
    matches <- regmatches(sharing_url, regexpr("[uU]!.+?![^&]+", sharing_url))
    if (length(matches) > 0) {
      return(matches[1])
    }
  }
  
  # If we can't parse it, just return the URL
  return(sharing_url)
}

# Upload a file to a shared folder
upload_file_to_shared_folder <- function(sharing_url, file_path) {
  cat(sprintf("Testing upload to shared folder: %s\n", sharing_url))
  cat(sprintf("File to upload: %s\n", file_path))
  
  # Verify the file exists
  if (!file.exists(file_path)) {
    cat(sprintf("Error: File '%s' does not exist.\n", file_path))
    return(list(success = FALSE, message = "File not found"))
  }
  
  # Get file info
  file_info <- file.info(file_path)
  file_size <- file_info$size
  file_name <- basename(file_path)
  
  cat(sprintf("File size: %d bytes\n", file_size))
  cat(sprintf("File name: %s\n", file_name))
  
  # Extract the sharing token from the URL
  token <- extract_sharing_token(sharing_url)
  cat(sprintf("Extracted token: %s\n", token))
  
  # Try multiple API approaches for upload

  # Approach 1: Graph API - Direct upload to shared folder
  cat("\nTrying Microsoft Graph API upload approach...\n")
  
  graph_api_url <- sprintf("https://graph.microsoft.com/v1.0/shares/%s/driveItem/children/%s/content", 
                     URLencode(token, reserved = TRUE),
                     URLencode(file_name, reserved = TRUE))
  
  cat(sprintf("Graph API URL: %s\n", graph_api_url))
  
  # Read file content
  file_content <- readBin(file_path, "raw", file_size)
  
  # Attempt upload
  tryCatch({
    req <- request(graph_api_url) %>%
      req_method("PUT") %>%
      req_body_raw(file_content) %>%
      req_error(is_error = function(resp) FALSE) # Don't error on HTTP errors
    
    resp <- req_perform(req)
    
    status <- resp_status(resp)
    cat(sprintf("API status: %d\n", status))
    
    if (status >= 200 && status < 300) {
      body <- resp_body_json(resp)
      cat("Response body:\n")
      print(body)
      
      cat("\nSUCCESS: File uploaded using Graph API!\n")
      return(list(success = TRUE, method = "graph_api", response = body))
    } else {
      body <- resp_body_string(resp)
      cat(sprintf("Graph API upload failed with status %d: %s\n", 
                  status, substring(body, 1, 500)))
    }
  }, error = function(e) {
    cat(sprintf("Error during Graph API upload: %s\n", e$message))
  })

  # Approach 2: OneDrive API - Direct upload
  cat("\nTrying OneDrive API upload approach...\n")
  
  onedrive_api_url <- sprintf("https://api.onedrive.com/v1.0/shares/%s/root:/children/%s:/content", 
                           URLencode(token, reserved = TRUE),
                           URLencode(file_name, reserved = TRUE))
  
  cat(sprintf("OneDrive API URL: %s\n", onedrive_api_url))
  
  tryCatch({
    req <- request(onedrive_api_url) %>%
      req_method("PUT") %>%
      req_body_raw(file_content) %>%
      req_error(is_error = function(resp) FALSE)
    
    resp <- req_perform(req)
    
    status <- resp_status(resp)
    cat(sprintf("API status: %d\n", status))
    
    if (status >= 200 && status < 300) {
      body <- resp_body_json(resp)
      cat("Response body:\n")
      print(body)
      
      cat("\nSUCCESS: File uploaded using OneDrive API!\n")
      return(list(success = TRUE, method = "onedrive_api", response = body))
    } else {
      body <- resp_body_string(resp)
      cat(sprintf("OneDrive API upload failed with status %d: %s\n", 
                  status, substring(body, 1, 500)))
    }
  }, error = function(e) {
    cat(sprintf("Error during OneDrive API upload: %s\n", e$message))
  })

  # Approach 3: Try using multipart upload
  cat("\nTrying multipart upload approach...\n")
  
  multipart_url <- sprintf("https://graph.microsoft.com/v1.0/shares/%s/driveItem/children", 
                         URLencode(token, reserved = TRUE))
  
  cat(sprintf("Multipart URL: %s\n", multipart_url))
  
  tryCatch({
    # Create a temporary file with JSON metadata
    metadata <- list(
      name = file_name,
      file = list(),
      "@microsoft.graph.conflictBehavior" = "rename"
    )
    
    req <- request(multipart_url) %>%
      req_method("POST") %>%
      req_headers("Content-Type" = "application/json") %>%
      req_body_json(metadata) %>%
      req_error(is_error = function(resp) FALSE)
    
    resp <- req_perform(req)
    
    status <- resp_status(resp)
    cat(sprintf("Multipart metadata status: %d\n", status))
    
    if (status >= 200 && status < 300) {
      body <- resp_body_json(resp)
      
      # Now upload the content using the upload URL
      if (!is.null(body$`@microsoft.graph.uploadUrl`)) {
        upload_url <- body$`@microsoft.graph.uploadUrl`
        cat(sprintf("Upload URL obtained: %s\n", upload_url))
        
        content_req <- request(upload_url) %>%
          req_method("PUT") %>%
          req_body_raw(file_content) %>%
          req_error(is_error = function(resp) FALSE)
        
        content_resp <- req_perform(content_req)
        
        content_status <- resp_status(content_resp)
        cat(sprintf("Content upload status: %d\n", content_status))
        
        if (content_status >= 200 && content_status < 300) {
          content_body <- resp_body_json(content_resp)
          cat("Content upload response:\n")
          print(content_body)
          
          cat("\nSUCCESS: File uploaded using multipart approach!\n")
          return(list(success = TRUE, method = "multipart", response = content_body))
        } else {
          content_body <- resp_body_string(content_resp)
          cat(sprintf("Content upload failed with status %d: %s\n", 
                      content_status, substring(content_body, 1, 500)))
        }
      } else {
        cat("No upload URL found in response.\n")
        print(body)
      }
    } else {
      body <- resp_body_string(resp)
      cat(sprintf("Multipart metadata failed with status %d: %s\n", 
                  status, substring(body, 1, 500)))
    }
  }, error = function(e) {
    cat(sprintf("Error during multipart upload: %s\n", e$message))
  })

  # If we get here, all approaches failed
  cat("\nFAILURE: All upload approaches failed.\n")
  return(list(success = FALSE, message = "All upload approaches failed"))
}

# ========== Main Test Script ==========

# Ask user for a OneDrive folder sharing link
cat("Please enter a OneDrive sharing link to a folder:\n")
cat("(This should be a link to a folder, not a file)\n")
sharing_url <- readline(prompt = "Folder sharing URL: ")

if (nchar(sharing_url) < 10) {
  cat("Invalid URL provided. Please provide a valid folder sharing link.\n")
  cat("Test aborted.\n")
  quit(status = 1)
}

# Create a test file to upload
test_file_path <- tempfile(fileext = ".txt")
cat("Creating test file...\n")
writeLines(paste("Test file created at", Sys.time(), 
                "for OneDrive upload test from JHEEM application"), 
          test_file_path)
cat(sprintf("Test file created at: %s\n", test_file_path))

# Test uploading file to the folder
result <- upload_file_to_shared_folder(sharing_url, test_file_path)

# Show final results
if (result$success) {
  cat("\nOVERALL RESULT: SUCCESS!\n")
  cat(sprintf("Successfully uploaded file using the %s method.\n", result$method))
  cat("This proves we can upload files to a shared folder.\n")
  cat("This approach can be used for implementing the cache storage.\n")
} else {
  cat("\nOVERALL RESULT: FAILURE\n")
  cat("Could not upload files to the shared folder.\n")
  cat("This suggests we may need a different approach for cache storage.\n")
  cat("Options include:\n")
  cat("1. Using pre-authenticated API access (requiring admin approval)\n")
  cat("2. Using a different storage service with easier API access\n")
  cat("3. Limiting caching to local storage in the app\n")
}

# Clean up
if (file.exists(test_file_path)) {
  file.remove(test_file_path)
  cat("Test file removed.\n")
}
