#' Creates the about page
#' @param config Page configuration
#' @return Shiny UI element
create_about_page <- function(config) {
    # Load dependencies
    tags$div(
        # Include CSS
        tags$head(
            tags$link(rel = "stylesheet", type = "text/css", href = "css/components/common/page.css")
        ),

        # Render content
        create_about_content()
    )
}
