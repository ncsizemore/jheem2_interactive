#' Creates the overview page content
#' @param config Page configuration from overview.yaml
create_overview_content <- function(config) {
    tagList(
        tags$div(
            class = "overview-container",
            style = sprintf(
                "min-width: %s; max-width: %s;",
                config$layout$container$min_width,
                config$layout$container$max_width
            ),

            # Header
            tags$header(
                class = "overview-header",
                style = config$layout$header$padding,
                tags$h1(config$page$title),
                tags$h2(config$page$subtitle)
            ),

            # Description
            tags$p(config$page$description),

            # Main content grid
            tags$div(
                class = "overview-grid",

                # Demo section
                tags$div(
                    class = "overview-demo",
                    tags$h3(config$demo$title),
                    tags$img(
                        src = config$demo$image,
                        alt = config$demo$title,
                        width = config$demo$width
                    ),
                    tags$p(
                        class = "caption",
                        config$demo$caption
                    )
                ),

                # Getting Started section
                tags$div(
                    class = "overview-links",
                    tags$h3(config$getting_started$title),
                    # Map over sections
                    lapply(config$getting_started$sections, function(section) {
                        tags$p(
                            tags$a(
                                class = "overview-link",
                                onclick = sprintf(
                                    'Shiny.setInputValue("link_from_overview", "%s", {priority: "event"})',
                                    section$link
                                ),
                                section$title
                            ),
                            " ",
                            section$description
                        )
                    })
                )
            )
        )
    )
}
