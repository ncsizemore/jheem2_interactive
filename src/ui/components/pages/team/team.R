#' Creates the team page
#' @param config Application configuration
#' @return Shiny UI element
create_team_page <- function(config) {
    # Load team-specific config
    team_config <- get_page_config("team")

    # Render content
    create_team_content(team_config)
}
