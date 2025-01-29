#' Validate custom configuration
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_custom_config <- function(config) {
    required_sections <- c(
        "subgroups",
        "demographics",
        "interventions"
    )

    missing <- setdiff(required_sections, names(config))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required custom configuration sections: %s",
            paste(missing, collapse = ", ")
        ))
    }
    TRUE
}
