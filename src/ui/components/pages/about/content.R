#' Creates the about page content
#' @param config Page configuration from about.yaml
#' @return Shiny UI element
create_about_content <- function(config) {
    tagList(
        # Navigation
        tags$nav(
            class = "page-nav",
            lapply(config$navigation$links, function(link) {
                tags$a(href = paste0("#", link$id), link$text)
            })
        ),
        tags$div(
            class = config$layout$container$class,

            # Header
            tags$header(
                class = config$layout$header$class,
                tags$h1(config$page$title),
                tags$h2(config$page$subtitle)
            ),

            # Content sections
            tags$div(
                class = config$layout$content$class,
                lapply(names(config$content$sections), function(section_id) {
                    section <- config$content$sections[[section_id]]
                    create_content_section(section_id, section, config)
                })
            )
        )
    )
}
