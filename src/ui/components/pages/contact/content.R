#' Creates the contact page content
#' @param config Page configuration from contact.yaml
#' @return Shiny UI element
create_contact_content <- function(config) {
    tagList(
        tags$div(
            class = config$layout$container$class,

            # Header
            tags$header(
                class = "page-header",
                tags$h1(config$page$title),
                tags$h2(config$page$subtitle),
                tags$p(config$page$description)
            ),

            # Contact form
            create_contact_form(config)
        )
    )
}
