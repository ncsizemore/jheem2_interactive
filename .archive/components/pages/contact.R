# components/pages/contact.R

#' Create contact form content
#' @param config Page configuration
#' @return Shiny UI element
create_contact_content <- function(config) {
    contact_config <- config$pages$contact
    
    tags$div(
        class = "contact-container",
        tags$div(style = 'height: 25px'),
        tags$div(
            class = 'contact',
            tags$table(
                # Header
                tags$tr(
                    tags$td(
                        colspan = '2',
                        class = 'contact_header header_color',
                        tags$h1(contact_config$title)
                    )
                ),
                
                # Description
                tags$tr(
                    tags$td(
                        colspan = '2',
                        tags$p(contact_config$description)
                    )
                ),
                
                # Form inputs
                tags$tr(
                    # Name and email column
                    tags$td(
                        fluidRow(
                            textInput(
                                inputId = 'feedback_name',
                                label = contact_config$form$name$label
                            )
                        ),
                        fluidRow(
                            textInput(
                                inputId = 'feedback_email',
                                label = contact_config$form$email$label
                            )
                        )
                    ),
                    
                    # Message column
                    tags$td(
                        textAreaInput(
                            inputId = 'feedback_contents',
                            label = contact_config$form$message$label,
                            placeholder = contact_config$form$message$placeholder,
                            height = contact_config$form$message$height,
                            width = contact_config$form$message$width
                        )
                    )
                ),
                
                # Submit button
                tags$tr(
                    tags$td(
                        colspan = '2',
                        style = 'text-align: center',
                        actionButton(
                            class = contact_config$submit$class,
                            inputId = 'feedback_submit',
                            label = contact_config$submit$label
                        ),
                        tags$div(style = 'height:20px')
                    )
                )
            )
        )
    )
}