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
#' @param selector_id String identifier matching config (e.g., "location")
#' @param page_type String identifying the page ("prerun" or "custom")
#' @param config The pre-loaded page configuration object
#' @param condition Optional condition for when selector should display
#' @return A Shiny UI element or NULL if selector not configured
create_selector <- function(selector_id, page_type, config, condition = NULL) {
    # Validate config input
    if (missing(config) || !is.list(config)) {
        stop("create_selector requires a valid 'config' object.")
    }

    # Try to find selector config in either selectors or directly in config
    selector_config <- config$selectors[[selector_id]] %||% config[[selector_id]]

    # Return NULL if selector is not configured
    if (is.null(selector_config)) {
        return(NULL)
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
    # # Debug print
    # print(paste("Creating input:", id, "of type:", type))
    # print("Config:")
    # str(config) # Commented out

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

    # print("Choices structured as:") # Commented out
    # str(choices) # Commented out
    # print(paste("Default value:", config$value)) # Commented out

    # Get show_label setting with default = TRUE for backward compatibility
    show_label <- config$show_label %||% TRUE

    # Get show_description setting with default = TRUE for backward compatibility
    show_description <- config$show_description %||% TRUE

    # Create the base input element
    input_element <- switch(type,
        "select" = if (input_style == "choices") {
            # print("Creating choices select with defaults:") # Commented out
            # print(paste("Selected:", config$value)) # Commented out
            choicesSelectInput(
                inputId = id,
                label = config$label,
                choices = choices,
                selected = config$value, # Pass through the default value
                multiple = multiple,
                placeholder = config$placeholder %||% config$label,
                show_label = show_label,
                show_description = show_description,
                description = config$description
            )
        } else {
            selectInput(
                inputId = id,
                label = config$label,
                choices = setNames(
                    sapply(choices, `[[`, "value"),
                    sapply(choices, `[[`, "label")
                ),
                selected = config$value, # Pass through the default value
                multiple = multiple
            )
        },
        "radio" = radioButtons(
            inputId = id,
            label = config$label,
            choices = setNames(
                sapply(choices, `[[`, "value"),
                sapply(choices, `[[`, "label")
            ),
            selected = config$value # Pass through the default value
        ),
        "checkbox" = checkboxInput(
            inputId = id,
            label = config$label,
            value = config$value # Already properly passed through
        ),
        "numeric" = tags$div(
            class = "numeric-input-container",
            numericInput(
                inputId = id,
                label = config$label,
                value = config$value, # Already properly passed through
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

# Note: The helper functions below now require the 'config' object to be passed
# from where they are called (e.g., from section_builder.R).

#' Helper function for location selector
#' @param page_type String identifying the page type
#' @param config The pre-loaded page configuration object
#' @return Selector UI element or NULL if not configured
create_location_selector <- function(page_type, config) {
    if (missing(config) || !is.list(config)) {
        stop("create_location_selector requires a valid 'config' object.")
    }
    tags$div(
        class = "location-selector",
        create_selector(
            selector_id = "location",
            page_type = page_type,
            config = config # Pass config down
        )
    )
}

#' Create intervention selector if configured
#' @param page_type String identifying the page type
#' @param config The pre-loaded page configuration object
#' @return Selector UI element or NULL if not configured
create_intervention_selector <- function(page_type, config) {
    if (missing(config) || !is.list(config)) {
        stop("create_intervention_selector requires a valid 'config' object.")
    }
    if (!is.null(config$intervention_aspects)) {
        create_selector(
            selector_id = "intervention_aspects",
            page_type = page_type,
            config = config, # Pass config down
            condition = sprintf("input.int_location_%s !== 'none'", page_type)
        )
    } else {
        NULL
    }
}

#' Create population selector if configured
#' @param page_type String identifying the page type
#' @param config The pre-loaded page configuration object
#' @return Selector UI element or NULL if not configured
create_population_selector <- function(page_type, config) {
    if (missing(config) || !is.list(config)) {
        stop("create_population_selector requires a valid 'config' object.")
    }
    if (!is.null(config$population_groups)) {
        create_selector(
            selector_id = "population_groups",
            page_type = page_type,
            config = config, # Pass config down
            condition = sprintf("input.int_aspect_%s !== 'none'", page_type)
        )
    } else {
        NULL
    }
}

#' Create timeframe selector if configured
#' @param page_type String identifying the page type
#' @param config The pre-loaded page configuration object
#' @return Selector UI element or NULL if not configured
create_timeframe_selector <- function(page_type, config) {
    if (missing(config) || !is.list(config)) {
        stop("create_timeframe_selector requires a valid 'config' object.")
    }
    if (!is.null(config$timeframes)) {
        create_selector(
            selector_id = "timeframes",
            page_type = page_type,
            config = config, # Pass config down
            condition = sprintf(
                "input.int_aspect_%s !== 'none' && input.int_tpop_%s !== ''",
                page_type,
                page_type
            )
        )
    } else {
        NULL
    }
}

#' Create intensity selector if configured
#' @param page_type String identifying the page type
#' @param config The pre-loaded page configuration object
#' @return Selector UI element or NULL if not configured
create_intensity_selector <- function(page_type, config) {
    if (missing(config) || !is.list(config)) {
        stop("create_intensity_selector requires a valid 'config' object.")
    }
    if (!is.null(config$intensities)) {
        create_selector(
            selector_id = "intensities",
            page_type = page_type,
            config = config, # Pass config down
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
    } else {
        NULL
    }
}
