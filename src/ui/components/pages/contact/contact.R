#' Creates the contact page
#' @param config Application configuration
#' @return Shiny UI element
create_contact_page <- function(config) {
    # Load contact-specific config
    contact_config <- get_page_config("contact")

    # Render content
    create_contact_content(contact_config)
}
