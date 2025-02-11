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
    print("\n=== Creating Choices Select ===")
    print(paste("Input ID:", inputId))
    print("Selected values:")
    str(selected)
    print("Choices:")
    str(choices)

    # Create select element
    select_tag <- tags$select(
        id = inputId,
        class = "choices-select",
        multiple = if (multiple) "multiple" else NULL
    )

    # Add options with selected state
    for (choice in choices) {
        is_selected <- !is.null(selected) && choice$value %in% selected
        print(sprintf("Option: %s, Selected: %s", choice$value, is_selected))

        select_tag <- tagAppendChild(
            select_tag,
            tags$option(
                value = choice$value,
                selected = if (is_selected) "selected" else NULL,
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

    container
}
