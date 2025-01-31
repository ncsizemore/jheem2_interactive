#' Creates the contact page content
#' @param config Page configuration from contact.yaml
#' @return Shiny UI element
create_contact_content <- function(config) {
    # Debug print
    print("Contact config received:")
    print(str(config))

    tags$div(
        class = config$layout$container$class,
        style = "max-width: 800px; margin: 0 auto; padding: 20px;",

        # Main content container
        tags$div(
            class = "contact-inner",
            style = "background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);",

            # Header
            tags$div(
                class = "page-header text-center",
                style = "margin-bottom: 30px;",
                tags$h1(
                    style = "color: #333; margin-bottom: 15px;",
                    config$page$title
                ),
                tags$h2(
                    style = "color: #666; font-size: 1.2em; margin-bottom: 15px;",
                    config$page$subtitle
                ),
                tags$p(
                    style = "color: #777;",
                    config$page$description
                )
            ),

            # Contact form
            create_contact_form(config)
        )
    )
}
