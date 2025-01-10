#' Configuration manager for intervention settings
#' @return Environment containing intervention configuration options
get_intervention_config <- function() {
    config <- new.env(parent = baseenv())
    config$HTML <- shiny::HTML
    source('config/interventions/options.R', local = config)
    return(config)
}