# components/selectors/base.R

library(shiny)

#' Wrap UI element in a conditional panel
#' @param element UI element to wrap
#' @param condition JavaScript condition as string
#' @return Conditional panel containing the element
wrap_in_conditional <- function(element, condition) {
    conditionalPanel(
        condition = condition,
        element
    )
}


#' Create a selector component
#' @param selector_id String identifier matching config (e.g., "location")
#' @param page_type String identifying the page ("prerun" or "custom")
#' @param condition Optional condition for when selector should display
#' @return A Shiny UI element
create_selector <- function(selector_id, page_type, condition = NULL) {
    # Load configuration
    config <- get_page_complete_config(page_type)

    # Try to find selector config in either selectors or directly in config
    selector_config <- config$selectors[[selector_id]] %||% config[[selector_id]]

    if (is.null(selector_config)) {
        stop(sprintf("No configuration found for selector: %s", selector_id))
    }

    # Generate input ID
    input_id <- generate_input_id(selector_id, page_type)

    # Create the appropriate input based on type
    input_element <- create_input_by_type(
        type = selector_config$type,
        id = input_id,
        config = selector_config
    )

    # Add wrapper classes
    input_element <- tags$div(
        class = paste(
            "selector-component",
            sprintf("selector-%s", selector_id)
        ),
        input_element
    )

    # Wrap in conditional panel if condition provided
    if (!is.null(condition)) {
        input_element <- wrap_in_conditional(input_element, condition)
    }

    input_element
}

#' Create input element based on type
#' @param type Type of input to create
#' @param id Input ID
#' @param config Configuration for the input
#' @return Shiny input element
create_input_by_type <- function(type, id, config) {
    # Ensure default values based on type
    config$value <- config$value %||% switch(type,
        "checkbox" = FALSE,
        "numeric" = 0,
        "select" = NULL,
        NULL
    )

    # Get base input type configuration
    base_config <- get_config_value(
        get_defaults_config(),
        c("input_types", type),
        default = list(default_style = NULL, multiple = FALSE)
    )

    # Merge with specific config
    input_style <- config$input_style %||% base_config$default_style
    multiple <- config$multiple %||% base_config$multiple

    # Create structured choices from options if present
    choices <- if (!is.null(config$options)) {
        lapply(names(config$options), function(name) {
            option <- config$options[[name]]
            list(
                value = option$id %||% name,
                label = option$label %||% name
            )
        })
    } else {
        list()
    }

    # Create the base input element
    input_element <- switch(type,
        "select" = if (input_style == "choices") {
            choicesSelectInput(
                inputId = id,
                label = NULL,
                choices = choices,
                multiple = multiple,
                placeholder = config$placeholder %||% config$label
            )
        } else {
            selectInput(
                inputId = id,
                label = config$label,
                choices = setNames(
                    sapply(choices, `[[`, "value"),
                    sapply(choices, `[[`, "label")
                ),
                multiple = multiple
            )
        },
        "radio" = radioButtons(
            inputId = id,
            label = config$label,
            choices = setNames(
                sapply(choices, `[[`, "value"),
                sapply(choices, `[[`, "label")
            )
        ),
        "checkbox" = checkboxInput(
            inputId = id,
            label = config$label,
            value = config$value
        ),
        "numeric" = tags$div(
            class = "numeric-input-container",
            numericInput(
                inputId = id,
                label = config$label,
                value = config$value,
                min = config$min %||% NA,
                max = config$max %||% NA,
                step = config$step %||% 1
            ),
            tags$div(
                class = "input-error-message",
                id = paste0(id, "_error"),
                style = "display: none;"
            )
        ),
        stop(sprintf("Unknown input type: %s", type))
    )

    # Wrap in validation container for validatable types
    if (type %in% c("numeric", "select")) {
        input_element <- tags$div(
            class = paste("input-validation-wrapper", type),
            input_element
        )
    }

    input_element
}

#' Create structured choices from configuration
#' @param options Options configuration
#' @return Named vector of choices
create_choices_from_config <- function(options) {
    setNames(
        sapply(options, `[[`, "id"),
        sapply(options, `[[`, "label")
    )
}

#' Generate standardized input ID
#' @param selector_id Base selector ID
#' @param page_type Page type
#' @return Standardized input ID
generate_input_id <- function(selector_id, page_type) {
    paste("int", selector_id, page_type, sep = "_")
}

#' Helper functions to maintain current API
create_location_selector <- function(id, config) {
    tags$div(
        class = "location-selector",
        create_selector(
            selector_id = "location",
            page_type = sub("int_location_", "", id)
        )
    )
}

create_intervention_selector <- function(page_type) {
    create_selector(
        "intervention_aspects",
        page_type,
        condition = sprintf("input.int_location_%s !== 'none'", page_type)
    )
}

create_population_selector <- function(page_type) {
    create_selector(
        "population_groups",
        page_type,
        condition = sprintf("input.int_aspect_%s !== 'none'", page_type)
    )
}

create_timeframe_selector <- function(page_type) {
    create_selector(
        "timeframes",
        page_type,
        condition = sprintf(
            "input.int_aspect_%s !== 'none' && input.int_tpop_%s !== ''",
            page_type,
            page_type
        )
    )
}

create_intensity_selector <- function(page_type) {
    create_selector(
        "intensities",
        page_type,
        condition = sprintf(
            paste(
                "input.int_aspect_%s !== 'none'",
                "input.int_tpop_%s !== ''",
                "input.int_timeframe_%s !== ''",
                sep = " && "
            ),
            page_type, page_type, page_type
        )
    )
}
