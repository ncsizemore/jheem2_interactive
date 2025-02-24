# components/selectors/base.R

library(shiny)

#' Create a selector component
#' @param selector_id String identifier matching config (e.g., "location")
#' @param page_type String identifying the page ("prerun" or "custom")
#' @param condition Optional condition for when selector should display
#' @return A Shiny UI element
create_selector <- function(selector_id, page_type, condition = NULL) {
    # Load configuration
    config <- get_page_complete_config(page_type)
    selector_config <- config$selectors[[selector_id]]
    
    if (is.null(selector_config)) {
        stop(sprintf("No configuration found for selector: %s", selector_id))
    }
    
    # Generate input ID
    input_id <- generate_input_id(selector_id, page_type)
    
    # Create the appropriate input based on type
    input_element <- create_input_by_type(
        type = selector_config$type,
        id = input_id,
        label = selector_config$ui$label,
        options = selector_config$options
    )
    
    # Add wrapper classes
    input_element <- tags$div(
        class = paste(
            "selector-component",
            sprintf("selector-%s", selector_id),
            selector_config$ui$defaultClass %||% ""
        ),
        input_element
    )
    
    # Add popover if configured
    if (!is.null(selector_config$ui$popover)) {
        input_element <- add_popover(
            input_element,
            input_id,
            selector_config$ui$popover
        )
    }
    
    # Wrap in conditional panel if condition provided
    if (!is.null(condition)) {
        input_element <- wrap_in_conditional(input_element, condition)
    }
    
    input_element
}

#' Create input element based on type
#' @param type Type of input to create
#' @param id Input ID
#' @param label Input label
#' @param options Input options
#' @return Shiny input element
create_input_by_type <- function(type, id, label, options) {
    # Debug print
    print(sprintf("Creating input of type %s with id %s", type, id))
    print("Label:")
    print(label)
    print("Options:")
    print(options)
    
    choices <- create_choices_from_config(options)
    
    switch(type,
           "radio" = radioButtons(
               inputId = id,
               label = label,
               choices = choices,
               selected = "none"
           ),
           "select" = selectInput(
               inputId = id,
               label = label,
               choices = choices,
               selected = "none"
           ),
           "checkbox" = checkboxGroupInput(
               inputId = id,
               label = label,
               choices = choices
           ),
           stop(sprintf("Unknown input type: %s", type))
    )
}

#' Create radio input
#' @param id Input ID
#' @param label Input label
#' @param options Input options
create_radio_input <- function(id, label, options) {
    radioButtons(
        inputId = id,
        label = label,
        choices = create_choices_from_config(options),
        selected = "none"
    )
}

#' Create select input
#' @param id Input ID
#' @param label Input label
#' @param options Input options
create_select_input <- function(id, label, options) {
    selectInput(
        inputId = id,
        label = label,
        choices = create_choices_from_config(options),
        selected = "none"
    )
}

#' Create checkbox input group
#' @param id Input ID
#' @param label Input label
#' @param options Input options
create_checkbox_input <- function(id, label, options) {
    checkboxGroupInput(
        inputId = id,
        label = label,
        choices = create_choices_from_config(options)
    )
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

#' Add popover to input element
#' @param element Input element
#' @param id Input ID
#' @param popover_config Popover configuration
add_popover <- function(element, id, popover_config) {
    tags$div(
        element,
        make_popover(
            id,
            title = popover_config$title,
            content = popover_config$content,
            placement = popover_config$placement %||% "right"
        )
    )
}

#' Wrap element in conditional panel
#' @param element Element to wrap
#' @param condition Condition string
wrap_in_conditional <- function(element, condition) {
    conditionalPanel(
        condition = condition,
        element
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
create_location_selector <- function(page_type) {
    create_selector("location", page_type)
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