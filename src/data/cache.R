library(cachem)

# Global cache instances
.CACHE <- list()

#' Initialize caches based on config
#' @param config Cache configuration from get_component_config("caching")
initialize_caches <- function(config) {
    .CACHE$cache1 <<- cache_disk(
        max_size = config$cache1$max_size,
        evict = config$cache1$evict_strategy
    )

    .CACHE$cache2 <<- cache_disk(
        max_size = config$cache2$max_size,
        evict = config$cache2$evict_strategy
    )
}

#' Sanitize cache key to meet cachem requirements
#' @param key Original key
#' @return Sanitized key
sanitize_key <- function(key) {
    # Replace any non-alphanumeric characters with underscore
    # Convert to lowercase
    tolower(gsub("[^a-zA-Z0-9]", "_", key))
}

#' Check if a simset is cached
#' @param key Cache key
#' @return Boolean indicating if key exists in cache
is_cached <- function(key) {
    if (is.null(.CACHE$cache1)) {
        return(FALSE)
    }
    safe_key <- sanitize_key(key)
    !is.null(.CACHE$cache1$get(safe_key))
}

#' Get simset from cache
#' @param key Cache key
#' @return Cached simset or NULL if not found
get_from_cache <- function(key) {
    if (is.null(.CACHE$cache1)) {
        return(NULL)
    }
    safe_key <- sanitize_key(key)
    .CACHE$cache1$get(safe_key)
}

#' Store simset in cache
#' @param key Cache key
#' @param value Simset to cache
cache_simset <- function(key, value) {
    if (is.null(.CACHE$cache1)) {
        return(NULL)
    }
    safe_key <- sanitize_key(key)
    .CACHE$cache1$set(safe_key, value)
}
