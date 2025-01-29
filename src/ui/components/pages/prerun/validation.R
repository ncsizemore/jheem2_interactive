#' Validate prerun configuration
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_prerun_config <- function(config) {
    # Check for required sections
    required_sections <- c(
        "intervention_aspects",
        "population_groups",
        "timeframes",
        "intensities"
    )

    missing <- setdiff(required_sections, names(config))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required prerun configuration sections: %s",
            paste(missing, collapse = ", ")
        ))
    }
    TRUE
}
