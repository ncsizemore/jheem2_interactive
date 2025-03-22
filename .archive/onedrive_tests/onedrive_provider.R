# OneDrive provider for JHEEM2 disk cache
# Provides integration with Microsoft OneDrive for storage of simulation files

library(httr2)
library(jsonlite)
library(cachem)

#' Initialize the OneDrive provider
#' @param config OneDrive configuration from the caching.yaml file
#' @return OneDrive provider object
initialize_onedrive_provider <- function(config) {
  print("[ONEDRIVE_PROVIDER] Initializing OneDrive provider")
  
  # Validate configuration
  if (is.null(config)) {
    stop("[ONEDRIVE_PROVIDER] Configuration is NULL")
  }
  
  # Get credentials from config or environment
  client_id <- config$client_id %||% Sys.getenv("ONEDRIVE_CLIENT_ID")
  client_secret <- config$client_secret %||% Sys.getenv("ONEDRIVE_CLIENT_SECRET")
  tenant_id <- config$tenant_id %||% Sys.getenv("ONEDRIVE_TENANT_ID")
  
  # Validate credentials
  if (nchar(client_id) < 10 || nchar(client_secret) < 5 || nchar(tenant_id) < 10) {
    print("[ONEDRIVE_PROVIDER] Invalid credentials. Using stub provider.")
    return(create_stub_provider())
  }
  
  # Create folder in OneDrive if it doesn't exist
  remote_folder <- config$folder %||% "jheem-simulations"
  
  # Create the provider object
  provider <- list(
    client_id = client_id,
    client_secret = client_secret,
    tenant_id = tenant_id,
    remote_folder = remote_folder,
    token = NULL,
    token_expires = 0,
    config = config
  )
  
  # Initialize access token
  tryCatch({
    provider$token <- get_access_token(provider)
    print("[ONEDRIVE_PROVIDER] Successfully obtained access token")
    
    # Ensure the remote folder exists
    ensure_remote_folder_exists(provider, remote_folder)
  }, error = function(e) {
    print(sprintf("[ONEDRIVE_PROVIDER] Error initializing: %s", e$message))
  })
  
  # Add provider methods
  provider$save_file <- function(local_path, remote_path) {
    save_file_to_onedrive(provider, local_path, remote_path)
  }
  
  provider$get_file <- function(remote_path, local_path) {
    get_file_from_onedrive(provider, remote_path, local_path)
  }
  
  provider$file_exists <- function(remote_path) {
    file_exists_in_onedrive(provider, remote_path)
  }
  
  provider$delete_file <- function(remote_path) {
    delete_file_from_onedrive(provider, remote_path)
  }
  
  # Return the configured provider
  print("[ONEDRIVE_PROVIDER] Provider initialized successfully")
  return(provider)
}

#' Create a stub provider for testing
#' @return Stub provider object
create_stub_provider <- function() {
  print("[ONEDRIVE_PROVIDER] Creating stub provider")
  
  list(
    save_file = function(local_path, remote_path) {
      print(sprintf("[ONEDRIVE_PROVIDER] Would save %s to %s", local_path, remote_path))
      FALSE
    },
    
    get_file = function(remote_path, local_path) {
      print(sprintf("[ONEDRIVE_PROVIDER] Would get %s to %s", remote_path, local_path))
      FALSE
    },
    
    file_exists = function(remote_path) {
      print(sprintf("[ONEDRIVE_PROVIDER] Would check if %s exists", remote_path))
      FALSE
    },
    
    delete_file = function(remote_path) {
      print(sprintf("[ONEDRIVE_PROVIDER] Would delete %s", remote_path))
      FALSE
    }
  )
}

#' Get an access token using client credentials flow
#' @param provider OneDrive provider object
#' @return Access token string
get_access_token <- function(provider) {
  # Check if we have a valid token already
  current_time <- as.numeric(Sys.time())
  if (!is.null(provider$token) && provider$token_expires > (current_time + 60)) {
    return(provider$token)
  }
  
  # Prepare token request
  token_url <- sprintf("https://login.microsoftonline.com/%s/oauth2/v2.0/token", provider$tenant_id)
  
  # Make the request
  tryCatch({
    resp <- request(token_url) %>%
      req_method("POST") %>%
      req_body_form(
        client_id = provider$client_id,
        client_secret = provider$client_secret,
        scope = "https://graph.microsoft.com/.default",
        grant_type = "client_credentials"
      ) %>%
      req_error(is_error = function(resp) FALSE) %>%  # Handle errors manually
      req_perform()
    
    # Check for errors
    if (resp_status(resp) != 200) {
      body <- resp_body_string(resp)
      stop(sprintf("Failed to get token. Status: %d, Body: %s", 
                 resp_status(resp), substring(body, 1, 200)))
    }
    
    # Parse the response
    token_data <- resp_body_json(resp)
    if (!is.null(token_data$access_token)) {
      # Update token in provider
      provider$token <- token_data$access_token
      provider$token_expires <- current_time + token_data$expires_in
      return(token_data$access_token)
    } else {
      stop("No access token in response")
    }
  }, error = function(e) {
    stop(sprintf("Error getting access token: %s", e$message))
  })
}

#' Ensure the remote folder exists
#' @param provider OneDrive provider object
#' @param folder_name Folder name to create
#' @return TRUE if successful, FALSE otherwise
ensure_remote_folder_exists <- function(provider, folder_name) {
  # Get token
  token <- get_access_token(provider)
  
  # Check if folder exists
  folder_path <- sprintf("drive/root:/%s", URLencode(folder_name, reserved = TRUE))
  folder_url <- sprintf("https://graph.microsoft.com/v1.0/me/%s", folder_path)
  
  folder_exists <- FALSE
  tryCatch({
    # Try to get folder info
    resp <- request(folder_url) %>%
      req_auth_bearer_token(token) %>%
      req_error(is_error = function(resp) FALSE) %>%
      req_perform()
    
    if (resp_status(resp) == 200) {
      folder_exists <- TRUE
    }
  }, error = function(e) {
    print(sprintf("[ONEDRIVE_PROVIDER] Error checking folder: %s", e$message))
  })
  
  # If folder doesn't exist, create it
  if (!folder_exists) {
    print(sprintf("[ONEDRIVE_PROVIDER] Creating folder: %s", folder_name))
    
    create_url <- "https://graph.microsoft.com/v1.0/me/drive/root/children"
    
    tryCatch({
      resp <- request(create_url) %>%
        req_auth_bearer_token(token) %>%
        req_method("POST") %>%
        req_headers("Content-Type" = "application/json") %>%
        req_body_json(list(
          name = folder_name,
          folder = list(),
          "@microsoft.graph.conflictBehavior" = "replace"
        )) %>%
        req_error(is_error = function(resp) FALSE) %>%
        req_perform()
      
      if (resp_status(resp) >= 200 && resp_status(resp) < 300) {
        print("[ONEDRIVE_PROVIDER] Folder created successfully")
        return(TRUE)
      } else {
        print(sprintf("[ONEDRIVE_PROVIDER] Failed to create folder. Status: %d", resp_status(resp)))
        body <- resp_body_string(resp)
        print(sprintf("Response: %s", substring(body, 1, 200)))
        return(FALSE)
      }
    }, error = function(e) {
      print(sprintf("[ONEDRIVE_PROVIDER] Error creating folder: %s", e$message))
      return(FALSE)
    })
  } else {
    print(sprintf("[ONEDRIVE_PROVIDER] Folder '%s' already exists", folder_name))
    return(TRUE)
  }
}

#' Save a file to OneDrive
#' @param provider OneDrive provider object
#' @param local_path Path to local file
#' @param remote_path Path in OneDrive (relative to root folder)
#' @return TRUE if successful, FALSE otherwise
save_file_to_onedrive <- function(provider, local_path, remote_path) {
  # Validate paths
  if (!file.exists(local_path)) {
    print(sprintf("[ONEDRIVE_PROVIDER] Local file not found: %s", local_path))
    return(FALSE)
  }
  
  # Get file info
  file_info <- file.info(local_path)
  file_size <- file_info$size
  
  # Format remote path to include the provider's remote folder
  full_remote_path <- file.path(provider$remote_folder, remote_path)
  full_remote_path <- gsub("\\\\", "/", full_remote_path)  # Normalize slashes
  
  # Get access token
  token <- get_access_token(provider)
  
  # Prepare upload URL
  upload_url <- sprintf("https://graph.microsoft.com/v1.0/me/drive/root:/%s:/content", 
                       URLencode(full_remote_path, reserved = TRUE))
  
  # Read file content
  file_content <- readBin(local_path, "raw", file_size)
  
  # Upload file
  tryCatch({
    print(sprintf("[ONEDRIVE_PROVIDER] Uploading %s to %s", local_path, full_remote_path))
    
    resp <- request(upload_url) %>%
      req_auth_bearer_token(token) %>%
      req_method("PUT") %>%
      req_body_raw(file_content) %>%
      req_error(is_error = function(resp) FALSE) %>%
      req_perform()
    
    if (resp_status(resp) >= 200 && resp_status(resp) < 300) {
      print(sprintf("[ONEDRIVE_PROVIDER] File uploaded successfully: %s", full_remote_path))
      return(TRUE)
    } else {
      print(sprintf("[ONEDRIVE_PROVIDER] Upload failed with status: %d", resp_status(resp)))
      body <- resp_body_string(resp)
      print(sprintf("Response: %s", substring(body, 1, 200)))
      return(FALSE)
    }
  }, error = function(e) {
    print(sprintf("[ONEDRIVE_PROVIDER] Upload error: %s", e$message))
    return(FALSE)
  })
}

#' Download a file from OneDrive
#' @param provider OneDrive provider object
#' @param remote_path Path in OneDrive (relative to root folder)
#' @param local_path Path to save the file locally
#' @return TRUE if successful, FALSE otherwise
get_file_from_onedrive <- function(provider, remote_path, local_path) {
  # Format remote path to include the provider's remote folder
  full_remote_path <- file.path(provider$remote_folder, remote_path)
  full_remote_path <- gsub("\\\\", "/", full_remote_path)  # Normalize slashes
  
  # Get access token
  token <- get_access_token(provider)
  
  # Prepare download URL
  download_url <- sprintf("https://graph.microsoft.com/v1.0/me/drive/root:/%s:/content", 
                         URLencode(full_remote_path, reserved = TRUE))
  
  # Download file
  tryCatch({
    print(sprintf("[ONEDRIVE_PROVIDER] Downloading %s to %s", full_remote_path, local_path))
    
    # Ensure the directory exists
    dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
    
    resp <- request(download_url) %>%
      req_auth_bearer_token(token) %>%
      req_error(is_error = function(resp) FALSE) %>%
      req_perform(path = local_path)
    
    if (resp_status(resp) >= 200 && resp_status(resp) < 300) {
      print(sprintf("[ONEDRIVE_PROVIDER] File downloaded successfully: %s", local_path))
      return(TRUE)
    } else {
      print(sprintf("[ONEDRIVE_PROVIDER] Download failed with status: %d", resp_status(resp)))
      body <- resp_body_string(resp)
      print(sprintf("Response: %s", substring(body, 1, 200)))
      return(FALSE)
    }
  }, error = function(e) {
    print(sprintf("[ONEDRIVE_PROVIDER] Download error: %s", e$message))
    return(FALSE)
  })
}

#' Check if a file exists in OneDrive
#' @param provider OneDrive provider object
#' @param remote_path Path in OneDrive (relative to root folder)
#' @return TRUE if exists, FALSE otherwise
file_exists_in_onedrive <- function(provider, remote_path) {
  # Format remote path to include the provider's remote folder
  full_remote_path <- file.path(provider$remote_folder, remote_path)
  full_remote_path <- gsub("\\\\", "/", full_remote_path)  # Normalize slashes
  
  # Get access token
  token <- get_access_token(provider)
  
  # Prepare request URL
  file_url <- sprintf("https://graph.microsoft.com/v1.0/me/drive/root:/%s", 
                    URLencode(full_remote_path, reserved = TRUE))
  
  # Check if file exists
  tryCatch({
    resp <- request(file_url) %>%
      req_auth_bearer_token(token) %>%
      req_error(is_error = function(resp) FALSE) %>%
      req_perform()
    
    if (resp_status(resp) == 200) {
      print(sprintf("[ONEDRIVE_PROVIDER] File exists: %s", full_remote_path))
      return(TRUE)
    } else {
      print(sprintf("[ONEDRIVE_PROVIDER] File does not exist: %s", full_remote_path))
      return(FALSE)
    }
  }, error = function(e) {
    print(sprintf("[ONEDRIVE_PROVIDER] Error checking file: %s", e$message))
    return(FALSE)
  })
}

#' Delete a file from OneDrive
#' @param provider OneDrive provider object
#' @param remote_path Path in OneDrive (relative to root folder)
#' @return TRUE if successful, FALSE otherwise
delete_file_from_onedrive <- function(provider, remote_path) {
  # Format remote path to include the provider's remote folder
  full_remote_path <- file.path(provider$remote_folder, remote_path)
  full_remote_path <- gsub("\\\\", "/", full_remote_path)  # Normalize slashes
  
  # Get access token
  token <- get_access_token(provider)
  
  # Prepare request URL
  delete_url <- sprintf("https://graph.microsoft.com/v1.0/me/drive/root:/%s", 
                       URLencode(full_remote_path, reserved = TRUE))
  
  # Delete file
  tryCatch({
    print(sprintf("[ONEDRIVE_PROVIDER] Deleting file: %s", full_remote_path))
    
    resp <- request(delete_url) %>%
      req_auth_bearer_token(token) %>%
      req_method("DELETE") %>%
      req_error(is_error = function(resp) FALSE) %>%
      req_perform()
    
    if (resp_status(resp) >= 200 && resp_status(resp) < 300) {
      print(sprintf("[ONEDRIVE_PROVIDER] File deleted successfully: %s", full_remote_path))
      return(TRUE)
    } else {
      print(sprintf("[ONEDRIVE_PROVIDER] Delete failed with status: %d", resp_status(resp)))
      return(FALSE)
    }
  }, error = function(e) {
    print(sprintf("[ONEDRIVE_PROVIDER] Delete error: %s", e$message))
    return(FALSE)
  })
}

#' Create cache wrapper for OneDrive provider
#' This will return a cachem-compatible cache object
#' @param config OneDrive configuration from the caching.yaml file
#' @return cachem-compatible cache object
create_onedrive_cache <- function(config) {
  print("[ONEDRIVE_PROVIDER] Creating OneDrive cache")
  
  # Initialize the OneDrive provider
  provider <- initialize_onedrive_provider(config)
  
  # Create a temporary directory for local cache
  temp_dir <- config$temp_path %||% file.path(tempdir(), "onedrive_cache")
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  
  print(sprintf("[ONEDRIVE_PROVIDER] Using temp directory: %s", temp_dir))
  
  # Create a disk cache for temporary storage
  disk_cache <- cache_disk(
    dir = temp_dir,
    max_size = config$max_size,
    evict = config$evict_strategy
  )
  
  # Wrap the disk cache with OneDrive synchronization
  onedrive_cache <- list(
    provider = provider,
    disk_cache = disk_cache,
    config = config,
    temp_dir = temp_dir
  )
  
  # Add OneDrive-aware cache methods
  onedrive_cache$set <- function(key, value) {
    # Save to local disk cache
    disk_cache$set(key, value)
    
    # Generate a file path for this key
    file_path <- file.path(temp_dir, paste0(key, ".RData"))
    
    # Save value to file
    if (!is.null(value)) {
      tryCatch({
        saveRDS(value, file_path)
        
        # Upload to OneDrive
        onedrive_path <- paste0(key, ".RData")
        provider$save_file(file_path, onedrive_path)
      }, error = function(e) {
        print(sprintf("[ONEDRIVE_CACHE] Error saving to OneDrive: %s", e$message))
      })
    }
  }
  
  onedrive_cache$get <- function(key) {
    # Try to get from local disk cache first
    value <- disk_cache$get(key)
    
    # If not found locally, try OneDrive
    if (is.null(value)) {
      onedrive_path <- paste0(key, ".RData")
      local_path <- file.path(temp_dir, paste0(key, ".RData"))
      
      if (provider$file_exists(onedrive_path)) {
        # Download from OneDrive
        success <- provider$get_file(onedrive_path, local_path)
        
        if (success && file.exists(local_path)) {
          # Load value from file
          tryCatch({
            value <- readRDS(local_path)
            
            # Cache it locally
            disk_cache$set(key, value)
          }, error = function(e) {
            print(sprintf("[ONEDRIVE_CACHE] Error loading from OneDrive: %s", e$message))
          })
        }
      }
    }
    
    return(value)
  }
  
  onedrive_cache$exists <- function(key) {
    # Check local cache first
    if (disk_cache$exists(key)) {
      return(TRUE)
    }
    
    # Check OneDrive
    onedrive_path <- paste0(key, ".RData")
    return(provider$file_exists(onedrive_path))
  }
  
  onedrive_cache$remove <- function(key) {
    # Remove from local cache
    disk_cache$remove(key)
    
    # Remove from OneDrive
    onedrive_path <- paste0(key, ".RData")
    provider$delete_file(onedrive_path)
  }
  
  onedrive_cache$reset <- function() {
    # Reset local cache
    disk_cache$reset()
    
    # We can't easily reset OneDrive storage, so just log a message
    print("[ONEDRIVE_CACHE] Reset requested. Local cache cleared but OneDrive cache remains.")
  }
  
  onedrive_cache$size <- function() {
    # Return size of local cache
    disk_cache$size()
  }
  
  onedrive_cache$keys <- function() {
    # Use local cache keys
    disk_cache$keys()
  }
  
  # Return the OneDrive cache object
  class(onedrive_cache) <- c("onedrive_cache", "disk_cache", "cachem_cache")
  print("[ONEDRIVE_PROVIDER] OneDrive cache created successfully")
  return(onedrive_cache)
}
