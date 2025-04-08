# src/ui/state/controls.R

#' Create a control state manager
#' @param session Shiny session object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param initial_settings Reactive source for initial settings
#' @return List of handler functions and reactive sources
create_control_manager <- function(session, page_id, id, initial_settings = NULL) {
    store <- get_store()
    ns <- session$ns
    
    # Get config defaults ONLY for the reset function
    config <- tryCatch(get_component_config("controls"), error = function(e){ NULL })
    config_defaults <- list( outcomes = NULL, facet.by = NULL, summary.type = "mean.and.interval" )
    if (!is.null(config)) {
       config_defaults$outcomes <- config$plot_controls$outcomes$defaults %||% NULL
       config_defaults$facet.by <- config$plot_controls$stratification$defaults %||% NULL
       config_defaults$summary.type <- config$plot_controls$summary_type$defaults %||% "mean.and.interval"
    }
    
    print(paste0("=== Control Manager Creation (page: ", page_id, ") - Stateless Version ==="))
    
    list(
        get_settings = function() {
            current_settings <- store$get_shared_control_state(page_id) # Calls new store method
            print(paste0("--- control_manager$get_settings (page: ", page_id, ") reading FROM STORE ---"))
            str(current_settings)
            if (is.null(current_settings)) { return(config_defaults) } # Fallback
            return(current_settings)
        },
        update_settings = function(settings) {
            if (is.null(settings)) { return() }
            if (!is.list(settings) || is.null(settings$outcomes) || is.null(settings$summary.type)) { 
                warning("Invalid settings passed to control_manager$update_settings")
                return() 
            }
            if (!"facet.by" %in% names(settings)) { settings$facet.by <- NULL }
            print(paste0("--- control_manager$update_settings (page: ", page_id, ") updating STORE ---"))
            str(settings)
            store$update_shared_control_state(page_id, settings) # Calls new store method
        },
        reset = function() {
            print(paste0("--- control_manager$reset (page: ", page_id, ") updating STORE ---"))
            store$update_shared_control_state(page_id, config_defaults) # Calls new store method
        }
    )
}
