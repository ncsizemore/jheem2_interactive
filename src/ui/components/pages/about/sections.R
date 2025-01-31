#' Creates a content section
#' @param section_id Section identifier
#' @param section Section configuration
#' @param config Page configuration
#' @return Shiny UI element
create_content_section <- function(section_id, section, config) {
    tags$section(
        id = section_id,
        class = config$layout$section$class,

        # Section title
        tags$h3(section$title),

        # Section content
        if (!is.null(section$content)) {
            tags$p(section$content)
        },

        # Figure if present
        if (!is.null(section$figure)) {
            create_figure(section$figure)
        },

        # List items if present
        if (!is.null(section$list)) {
            create_list(section$list)
        }
    )
}

#' Creates a figure element
#' @param figure_config Figure configuration
#' @return Shiny UI element
create_figure <- function(figure_config) {
    tags$figure(
        class = "page-figure",
        tags$img(
            src = figure_config$src,
            alt = figure_config$alt
        ),
        if (!is.null(figure_config$caption)) {
            tags$figcaption(
                lapply(figure_config$caption, function(caption_text) {
                    tagList(
                        tags$p(caption_text),
                        tags$br()
                    )
                })
            )
        }
    )
}

#' Creates a list element
#' @param list_config List configuration
#' @return Shiny UI element
create_list <- function(list_config) {
    if (list_config$type == "ordered") {
        tags$ol(
            lapply(list_config$items, function(item) {
                tags$li(
                    HTML(item$content) # Use HTML to handle bold tags in config
                )
            })
        )
    } else {
        tags$ul(
            lapply(list_config$items, function(item) {
                tags$li(
                    HTML(item$content)
                )
            })
        )
    }
}
