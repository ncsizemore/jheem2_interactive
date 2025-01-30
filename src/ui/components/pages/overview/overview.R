#' Creates the overview page
#' @param config Application configuration
create_overview_page <- function(config) {
    # Load overview-specific config
    overview_config <- get_page_config("overview")

    # Render content
    create_overview_content(overview_config)
}
