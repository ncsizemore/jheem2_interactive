# Test OneDrive folder access using sharing links
# This script tests if we can list files within a shared folder

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

# List files in a shared folder
list_files_in_shared_folder <- function(sharing_url) {
  cat(sprintf("Testing listing files in shared folder: %s\n", sharing_url))
  
  # Extract the sharing token from the URL
  token <- extract_sharing_token(sharing_url)
  cat(sprintf("Extracted token: %s\n", token))
  
  # Construct API URL for accessing the shared folder
  # First try using Microsoft Graph API
  api_url <- sprintf("https://graph.microsoft.com/v1.0/shares/%s/driveItem/children", 
                     URLencode(token, reserved = TRUE))
  
  cat(sprintf("Trying Graph API URL: %s\n", api_url))
  
  # Attempt to list files using Microsoft Graph API
  tryCatch({
    req <- request(api_url) %>%
      req_method("GET") %>%
      req_error(is_error = function(resp) FALSE) # Don't error on HTTP errors
    
    resp <- req_perform(req)
    
    status <- resp_status(resp)
    cat(sprintf("API status: %d\n", status))
    
    if (status >= 200 && status < 300) {
      body <- resp_body_json(resp)
      cat("Response body:\n")
      print(body)
      
      if (!is.null(body$value)) {
        cat(sprintf("Found %d items in the folder.\n", length(body$value)))
        return(list(success = TRUE, items = body$value))
      } else {
        cat("No items found in the response.\n")
        return(list(success = FALSE, message = "No items in response"))
      }
    } else {
      body <- resp_body_string(resp)
      cat(sprintf("API request failed with status %d: %s\n", status, substring(body, 1, 500)))
      
      # Try alternative API approach
      cat("\nTrying alternative approach...\n")
      
      # For OneDrive Personal we could try the OneDrive API directly
      alt_api_url <- sprintf("https://api.onedrive.com/v1.0/shares/%s/root/children", 
                           URLencode(token, reserved = TRUE))
      
      cat(sprintf("Trying OneDrive API URL: %s\n", alt_api_url))
      
      alt_req <- request(alt_api_url) %>%
        req_method("GET") %>%
        req_error(is_error = function(resp) FALSE)
      
      alt_resp <- req_perform(alt_req)
      
      alt_status <- resp_status(alt_resp)
      cat(sprintf("Alternative API status: %d\n", alt_status))
      
      if (alt_status >= 200 && alt_status < 300) {
        alt_body <- resp_body_json(alt_resp)
        cat("Alternative response body:\n")
        print(alt_body)
        
        if (!is.null(alt_body$value)) {
          cat(sprintf("Found %d items in the folder.\n", length(alt_body$value)))
          return(list(success = TRUE, items = alt_body$value))
        } else {
          cat("No items found in the alternative response.\n")
        }
      } else {
        alt_body <- resp_body_string(alt_resp)
        cat(sprintf("Alternative API request failed with status %d: %s\n", 
                    alt_status, substring(alt_body, 1, 500)))
      }
      
      return(list(success = FALSE, message = "All API attempts failed"))
    }
  }, error = function(e) {
    cat(sprintf("Error during API request: %s\n", e$message))
    return(list(success = FALSE, message = e$message))
  })
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

# Test listing files in the folder
result <- list_files_in_shared_folder(sharing_url)

# Show results
if (result$success) {
  cat("\nSUCCESS: Listed files in shared folder!\n")
  
  # Display files
  cat("\nFiles in folder:\n")
  for (item in result$items) {
    cat(sprintf("- %s (%s)\n", 
                item$name, 
                if (!is.null(item$folder)) "Folder" else "File"))
  }
  
  cat("\nTest complete. This proves we can list files in a shared folder.\n")
} else {
  cat("\nFAILURE: Could not list files in shared folder.\n")
  cat("This suggests the API access to folder listings may be restricted.\n")
  cat("Consider testing the file upload feature separately.\n")
}
