#' Custom input binding for Choices.js select
#' @param inputId The input identifier
#' @param label Label for the input
#' @param choices List of choices
#' @param selected Initially selected value(s)
#' @param multiple Allow multiple selections
#' @param placeholder Placeholder text
choicesSelectInput <- function(inputId,
                               label,
                               choices,
                               selected = NULL,
                               multiple = FALSE,
                               placeholder = NULL) {
    # Print debug info
    print(sprintf("Creating choices select: %s", inputId))
    print("Inputs:")
    print(paste("inputId:", inputId))
    print(paste("multiple:", multiple))
    print(paste("placeholder:", placeholder))

    # Create select element
    select_tag <- tags$select(
        id = inputId,
        class = "choices-select",
        multiple = if (multiple) "multiple" else NULL
    )

    # Add options
    for (choice in choices) {
        select_tag <- tagAppendChild(
            select_tag,
            tags$option(
                value = choice$value,
                choice$label
            )
        )
    }

    # Debug each part of the script separately
    script_parts <- list(
        intro = sprintf("console.log('Initializing Choices for: %s');", inputId),
        config = sprintf("new Choices('#%s', {", inputId),
        options = paste(
            "  removeItemButton: true,",
            sprintf("  placeholder: %s,", tolower(!is.null(placeholder))),
            sprintf("  placeholderValue: '%s',", if (!is.null(placeholder)) placeholder else ""),
            "  shouldSort: false"
        ),
        closing = "});"
    )

    print("Script parts:")
    str(script_parts)

    # Combine script parts
    init_script <- paste(
        script_parts$intro,
        script_parts$config,
        script_parts$options,
        script_parts$closing,
        sep = "\n"
    )

    print("Generated script:")
    print(init_script)

    # Create container
    container <- div(
        class = "choices-container",
        if (!is.null(label)) tags$label(class = "choices-label", label),
        select_tag,
        tags$script(HTML(init_script))
    )

    print("Container created:")
    print(container)

    container
}
