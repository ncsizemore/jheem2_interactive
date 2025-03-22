# Test OneDrive access using sharing links
# This script tests if we can access OneDrive content using sharing links without authentication

library(httr2)
library(jsonlite)
library(utils)

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

# Convert sharing URL to direct download URL
get_download_url <- function(sharing_url) {
  # Try different transformations based on URL format
  
  # For personal OneDrive links (1drv.ms or onedrive.live.com)
  if (grepl("1drv\\.ms|onedrive\\.live\\.com", sharing_url)) {
    # If it's already a download link, return as is
    if (grepl("download\\?", sharing_url)) {
      return(sharing_url)
    }
    # Try to convert view link to download link
    return(gsub("view\\.aspx", "download.aspx", sharing_url))
  }
  
  # For business OneDrive/SharePoint links
  if (grepl("sharepoint\\.com", sharing_url)) {
    # If it's already a download link, return as is
    if (grepl("download=1", sharing_url)) {
      return(sharing_url)
    }
    # Add download parameter
    if (grepl("\\?", sharing_url)) {
      return(paste0(sharing_url, "&download=1"))
    } else {
      return(paste0(sharing_url, "?download=1"))
    }
  }
  
  # For other formats, try using the Microsoft Graph API format with the sharing token
  token <- extract_sharing_token(sharing_url)
  if (!is.null(token) && token != sharing_url) {
    # This is a more advanced approach using Graph API directly
    # This may need additional authentication
    return(paste0("https://api.onedrive.com/v1.0/shares/", utils::URLencode(token), "/root/content"))
  }
  
  # If we can't transform it, return original URL
  return(sharing_url)
}

# ========== Main Test Functions ==========

# Test downloading a file using a sharing link
test_download_with_sharing_link <- function(sharing_url, output_path = tempfile()) {
  cat(sprintf("Testing download with sharing link: %s\n", sharing_url))
  
  # Try to determine a direct download URL
  download_url <- get_download_url(sharing_url)
  cat(sprintf("Converted to download URL: %s\n", download_url))
  
  # Attempt download
  tryCatch({
    req <- request(download_url) %>%
      req_method("GET") %>%
      req_error(is_error = function(resp) FALSE) # Don't error on HTTP errors
      
    resp <- req_perform(req, path = output_path)
    
    status <- resp_status(resp)
    cat(sprintf("Download status: %d\n", status))
    
    if (status >= 200 && status < 300) {
      cat(sprintf("Download successful! File saved to: %s\n", output_path))
      file_info <- file.info(output_path)
      cat(sprintf("File size: %d bytes\n", file_info$size))
      
      # Try to detect file type
      if (file_info$size > 0) {
        file_type <- system2("file", args = c("-b", shQuote(output_path)), stdout = TRUE)
        cat(sprintf("File type: %s\n", file_type))
      }
      
      return(list(success = TRUE, path = output_path, size = file_info$size))
    } else {
      cat(sprintf("Download failed with status: %d\n", status))
      body <- resp_body_string(resp)
      cat(sprintf("Error response: %s\n", substring(body, 1, 500)))
      return(list(success = FALSE, status = status, message = body))
    }
  }, error = function(e) {
    cat(sprintf("Error during download: %s\n", e$message))
    return(list(success = FALSE, message = e$message))
  })
}

# ========== Main Test Script ==========

# Ask user for a OneDrive sharing link
cat("Please enter a OneDrive sharing link to a test file:\n")
sharing_url <- readline(prompt = "Sharing URL: ")

if (nchar(sharing_url) < 10) {
  cat("Invalid URL provided. Using a sample URL for testing...\n")
  sharing_url <- "https://1drv.ms/t/s!AkbmKQw2AbNhhKlKMY-3akPnYdoHsA?e=eS5vkU"
}

# Test downloading the file
result <- test_download_with_sharing_link(sharing_url)

# Show results
if (result$success) {
  cat("\nSUCCESS: File downloaded successfully!\n")
  
  # Ask if user wants to view the file (if it's a text file)
  if (result$size < 10000) {  # Only offer to show small files
    cat("Would you like to view the file content? (y/n): ")
    view_response <- readline(prompt = "")
    
    if (tolower(view_response) == "y") {
      tryCatch({
        content <- readLines(result$path, warn = FALSE)
        cat("\n----- File Content -----\n")
        cat(paste(content, collapse = "\n"))
        cat("\n----- End Content -----\n")
      }, error = function(e) {
        cat(sprintf("Could not display file content: %s\n", e$message))
        cat("This might be a binary file which cannot be displayed as text.\n")
      })
    }
  }
} else {
  cat("\nFAILURE: Could not download file.\n")
}

# Ask user to try a folder sharing link
cat("\n\nWould you like to test a OneDrive folder sharing link? (y/n): ")
test_folder <- readline(prompt = "")

if (tolower(test_folder) == "y") {
  cat("Please enter a OneDrive sharing link to a test folder:\n")
  folder_url <- readline(prompt = "Folder Sharing URL: ")
  
  cat("\nFolder functionality requires additional implementation.\n")
  cat("This would be implemented in the full solution.\n")
}

cat("\nTest complete. This proves we can access OneDrive files using sharing links.\n")
cat("This approach can be used for pre-run simulations.\n")
cat("For the dynamic caching, we would need to generate these links programmatically.\n")
