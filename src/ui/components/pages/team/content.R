#' Creates the team page content
#' @param config Page configuration from src/ui/config/pages/team.yaml
create_team_content <- function(config) {
    tagList(
        tags$div(
            class = "page-container",
            # Header
            tags$header(
                class = "page-header",
                tags$h1(config$page$title),
                tags$h2(config$page$subtitle),
                tags$p(config$page$description)
            ),

            # Team grid
            tags$div(
                class = "team-grid",
                # Map over team members
                lapply(config$content$members, create_member_card)
            )
        )
    )
}
