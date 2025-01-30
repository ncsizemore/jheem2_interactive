#' Creates a contact form
#' @param config Form configuration from contact.yaml
#' @return Shiny UI element
create_contact_form <- function(config) {
    # Create form fields
    fields <- lapply(names(config$form$fields), function(field_name) {
        field <- config$form$fields[[field_name]]

        # Container for each field
        tags$div(
            class = "form-group",
            tags$label(
                `for` = field_name,
                field$label,
                if (field$required) tags$span(class = "required", "*")
            ),

            # Input element based on type
            if (field$type == "textarea") {
                tags$textarea(
                    id = field_name,
                    class = "form-control",
                    placeholder = field$placeholder,
                    rows = field$rows
                )
            } else {
                tags$input(
                    id = field_name,
                    type = field$type,
                    class = "form-control",
                    placeholder = field$placeholder
                )
            }
        )
    })

    # Create form
    tags$form(
        id = "contact-form",
        class = config$layout$form$class,
        style = sprintf(
            "width: %s; margin: %s;",
            config$layout$form$width,
            config$layout$form$margin
        ),

        # Add all fields
        fields,

        # Submit button
        tags$div(
            class = "form-group",
            tags$button(
                type = "submit",
                class = config$form$submit$class,
                config$form$submit$label
            )
        )
    )
}
