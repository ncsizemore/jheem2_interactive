#' Creates a contact form
#' @param config Form configuration from contact.yaml
#' @return Shiny UI element
create_contact_form <- function(config) {
    # Debug print
    print("Form config received:")
    print(str(config$form))

    tags$div(
        class = config$layout$form$class,
        style = "max-width: 500px; margin: 0 auto;",

        # Name input
        tags$div(
            class = "form-group",
            style = "margin-bottom: 20px;",
            textInput(
                inputId = "feedback_name",
                label = tags$span(
                    style = "font-weight: 500; color: #444;",
                    config$form$fields$name$label
                ),
                placeholder = config$form$fields$name$placeholder,
                width = "100%"
            )
        ),

        # Email input
        tags$div(
            class = "form-group",
            style = "margin-bottom: 20px;",
            textInput(
                inputId = "feedback_email",
                label = tags$span(
                    style = "font-weight: 500; color: #444;",
                    config$form$fields$email$label
                ),
                placeholder = config$form$fields$email$placeholder,
                width = "100%"
            )
        ),

        # Message input
        tags$div(
            class = "form-group",
            style = "margin-bottom: 25px;",
            textAreaInput(
                inputId = "feedback_contents",
                label = tags$span(
                    style = "font-weight: 500; color: #444;",
                    config$form$fields$message$label
                ),
                placeholder = config$form$fields$message$placeholder,
                height = "200px",
                width = "100%"
            )
        ),

        # Submit button
        tags$div(
            class = "form-group text-center",
            actionButton(
                inputId = "feedback_submit",
                label = config$form$submit$label,
                class = paste(config$form$submit$class, "btn-lg"),
                style = "min-width: 150px;"
            )
        )
    )
}
