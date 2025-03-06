# Utility functions for data operations

#' Normalize location code format
#' @param location_code Location code to normalize
#' @return Normalized location code
normalize_location_code <- function(location_code) {
    # Return as-is if NULL or not a character
    if (is.null(location_code) || !is.character(location_code)) {
        return(location_code)
    }
    
    # Strip whitespace and convert to uppercase
    location_code <- toupper(trimws(location_code))
    
    # If it's a numeric code with "C." prefix, ensure consistent format
    if (grepl("^C\\.[0-9]+$", location_code)) {
        # Extract the number part
        num_part <- as.numeric(gsub("C\\.", "", location_code))
        # Reformat consistently
        return(paste0("C.", num_part))
    }
    
    return(location_code)
}
