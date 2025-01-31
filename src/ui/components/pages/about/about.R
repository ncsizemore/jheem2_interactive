#' Creates the about page
#' @param config Application configuration
#' @return Shiny UI element
create_about_page <- function(config) {
    # Source dependencies
    source("src/ui/components/pages/about/sections.R")

    # Load about-specific config
    about_config <- get_page_config("about")

    # Create page with standard structure
    tags$div(
        class = "page-wrapper",
        # Include CSS
        tags$head(
            tags$link(rel = "stylesheet", type = "text/css", href = "css/components/common/page.css")
        ),

        # Render content
        create_about_content(about_config)
    )
}
