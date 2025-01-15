# components/display/plot_controls.R

#' Create a plot control panel
#' @param suffix Page suffix (prerun or custom)
#' @param config Configuration from get_page_complete_config
#' @return Shiny UI element
create_plot_control_panel <- function(suffix) {
    plot_config <- get_page_complete_config(suffix)$plot_controls
    
    tags$div(
        class = 'controls controls_narrow',
        
        # Outcomes selection
        checkboxGroupInput(
            inputId = paste0('outcomes_', suffix),
            label = plot_config$outcomes$label,
            choices = setNames(
                sapply(plot_config$outcomes$options, `[[`, "id"),
                sapply(plot_config$outcomes$options, `[[`, "label")
            )
        ),
        
        # Faceting selection
        radioButtons(
            inputId = paste0('facet_by_', suffix),
            label = plot_config$stratification$label,
            choices = setNames(
                sapply(plot_config$stratification$options, `[[`, "id"),
                sapply(plot_config$stratification$options, `[[`, "label")
            )
        ),
        
        # Summary type selection
        radioButtons(
            inputId = paste0('summary_type_', suffix),
            label = plot_config$display$label,
            choices = setNames(
                sapply(plot_config$display$options, `[[`, "id"),
                sapply(plot_config$display$options, `[[`, "label")
            )
        )
    )
}

#' Get current plot control settings
#' @param input Shiny input object
#' @param suffix Page suffix (prerun or custom)
#' @return List of plot control settings
get_control_settings <- function(input, suffix) {
    plot_config <- get_page_complete_config(suffix)$plot_controls
    
    # Default settings if input is not yet initialized
    if (is.null(input[[paste0('outcomes_', suffix)]]) ||
        is.null(input[[paste0('facet_by_', suffix)]]) ||
        is.null(input[[paste0('summary_type_', suffix)]])) {
        return(list(
            outcomes = sapply(head(plot_config$outcomes$options, 2), `[[`, "id"),
            facet.by = NULL,  # Default to no faceting
            summary.type = plot_config$display$options$mean$id
        ))
    }
    
    # Regular settings collection if inputs exist
    list(
        outcomes = get_selected_outcomes(input, suffix, plot_config),
        facet.by = get_selected_facet_by(input, suffix),
        summary.type = get_selected_summary_type(input, suffix, plot_config)
    )
}

#' Get selected outcomes
#' @param input Shiny input object
#' @param suffix Page suffix
#' @param plot_config Plot configuration
#' @return Vector of selected outcomes
get_selected_outcomes <- function(input, suffix, plot_config) {
    selected <- input[[paste0('outcomes_', suffix)]]
    if (is.null(selected)) {
        return(sapply(head(plot_config$outcomes$options, 2), `[[`, "id"))
    }
    selected
}

#' Get selected faceting option
#' @param input Shiny input object
#' @param suffix Page suffix
#' @return Selected faceting option or NULL
get_selected_facet_by <- function(input, suffix) {
    selected <- input[[paste0('facet_by_', suffix)]]
    if (is.null(selected) || selected == 'none') return(NULL)
    selected
}

#' Get selected summary type
#' @param input Shiny input object
#' @param suffix Page suffix
#' @param plot_config Plot configuration
#' @return Selected summary type
get_selected_summary_type <- function(input, suffix, plot_config) {
    selected <- input[[paste0('summary_type_', suffix)]]
    if (is.null(selected)) {
        return(plot_config$display$options$mean$id)
    }
    selected
}