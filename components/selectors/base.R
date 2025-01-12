#' Create a base selector component
#' @param selector_id String identifier matching the YAML config (e.g., "location", "intervention_aspects")
#' @param suffix String suffix for input IDs (e.g., "prerun")
#' @param config Configuration environment
#' @param condition Optional condition for when selector should display
#' @return A Shiny UI element
create_selector <- function(selector_id, suffix, config = get_intervention_config(), condition = NULL) {
    # Get configs
    selector_config <- config$UI_CONFIG[[selector_id]]
    options <- config[[toupper(selector_id)]]
    id <- paste0("int_", selector_id, "_", suffix)
    
    # Create core input element
    input_element <- if (selector_config$type == "radio") {
        radioButtons(
            inputId = id,
            label = selector_config$label,
            choiceNames = unname(sapply(options, function(opt) opt$label)),
            choiceValues = unname(sapply(options, function(opt) opt$id)),
            selected = "none"
        )
    } else if (selector_config$type == "select") {
        selectInput(
            inputId = id,
            label = selector_config$label,
            choices = setNames(
                unname(sapply(options, function(opt) opt$id)),
                unname(sapply(options, function(opt) opt$label))
            ),
            selected = "none"
        )
    }
    
    # Add popover if configured
    if (!is.null(selector_config$popover)) {
        input_element <- tags$div(
            input_element,
            make.popover(
                id,
                title = selector_config$popover$title,
                content = selector_config$popover$content,
                placement = "right"
            )
        )
    }
    
    # Wrap in conditional panel if condition provided
    if (!is.null(condition)) {
        input_element <- conditionalPanel(
            condition = sprintf(condition, suffix),
            input_element
        )
    }
    
    input_element
}

#' Helper to create specific selector types
#' These maintain the same interface as our current functions
create_location_selector <- function(suffix, config = get_intervention_config()) {
    create_selector("location", suffix, config)
}

create_intervention_selector <- function(suffix, config = get_intervention_config()) {
    create_selector(
        "intervention_aspects", 
        suffix, 
        config,
        condition = sprintf("input.int_location_%s !== 'none'", suffix)
    )
}

create_population_selector <- function(suffix, config = get_intervention_config()) {
    create_selector(
        "population_groups",
        suffix,
        config,
        condition = sprintf("input.int_aspect_%s !== 'none'", suffix)
    )
}

create_timeframe_selector <- function(suffix, config = get_intervention_config()) {
    create_selector(
        "timeframes",
        suffix,
        config,
        condition = sprintf("input.int_aspect_%s !== 'none' && input.int_tpop_%s !== ''", suffix, suffix)
    )
}

create_intensity_selector <- function(suffix, config = get_intervention_config()) {
    create_selector(
        "intensities",
        suffix,
        config,
        condition = sprintf(
            "input.int_aspect_%s !== 'none' && input.int_tpop_%s !== '' && input.int_timeframe_%s !== ''",
            suffix, suffix, suffix
        )
    )
}