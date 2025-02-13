#' Validate prerun configuration
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_prerun_config <- function(config) {
    # Get requirements from config
    defaults_config <- get_defaults_config()
    required_sections <- defaults_config$page_requirements$prerun$required_sections
    
    if (is.null(required_sections)) {
        warning("No requirements defined for prerun page")
        return(TRUE)
    }

    missing <- setdiff(required_sections, names(config))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required prerun configuration sections: %s",
            paste(missing, collapse = ", ")
        ))
    }
    TRUE
}