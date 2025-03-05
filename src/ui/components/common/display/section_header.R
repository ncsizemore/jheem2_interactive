#' Create a section header for grouping selectors
#' @param title Section title text
#' @param description Optional description text
#' @return Div element with formatted header
create_section_header <- function(title, description = NULL) {
    tagList(
        tags$div(
            class = "selector-section-header",
            tags$h5(
                class = "section-title",
                title
            ),
            if (!is.null(description)) {
                tags$div(
                    class = "section-description",
                    description
                )
            }
        )
    )
}
