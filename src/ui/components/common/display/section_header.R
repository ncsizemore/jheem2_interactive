#' Create a section header for grouping selectors
#' @param title Section title text
#' @param description Optional description text
#' @return Div element with formatted header
create_section_header <- function(title, description = NULL) {
    # Check if description is effectively the same as the title or a common pattern
    # like "Select {title}" to avoid duplication
    show_description <- !is.null(description) && 
                       !identical(description, title) && 
                       !identical(description, paste("Select", tolower(title))) && 
                       !identical(description, paste("Select the", tolower(title)))
    
    tagList(
        tags$div(
            class = "selector-section-header",
            tags$h5(
                class = "section-title",
                title
            ),
            if (show_description) {
                tags$div(
                    class = "section-description",
                    description
                )
            }
        )
    )
}
