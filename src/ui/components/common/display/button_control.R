# src/ui/components/common/display/button_control.R

#' Set redraw button enabled state
#' @param input Shiny input object
#' @param suffix Page suffix (prerun or custom)
#' @param enable Boolean to enable/disable button
set_redraw_button_enabled <- function(input, suffix, enable) {
    redraw_id <- paste0(suffix, "-toggle_plot")
    print(paste("Checking redraw button:", redraw_id))
    print(paste("Button exists:", !is.null(input[[redraw_id]])))
    if (!is.null(input[[redraw_id]])) {
        print(paste("Toggling state for", redraw_id, "to", enable))
        shinyjs::toggleState(redraw_id, condition = enable)
    }
}

#' Set share button enabled state
#' @param input Shiny input object
#' @param suffix Page suffix (prerun or custom)
#' @param enable Boolean to enable/disable button
set_share_button_enabled <- function(input, suffix, enable) {
    share_id <- paste0(suffix, "-toggle_table")
    print(paste("Checking share button:", share_id))
    print(paste("Button exists:", !is.null(input[[share_id]])))
    if (!is.null(input[[share_id]])) {
        print(paste("Toggling state for", share_id, "to", enable))
        shinyjs::toggleState(share_id, condition = enable)
    }
}

#' Sync button states with plot state
#' 
#' This function ensures that toggle buttons are enabled when data is available
#' for their respective pages. It ONLY enables buttons and never disables them,
#' which prevents a situation where generating plots on one page would inadvertently
#' disable toggle buttons on other pages.
#'
#' @param input Shiny input object
#' @param plot_and_table_list List containing plot and table data
sync_buttons_to_plot <- function(input, plot_and_table_list) {
    print("=== sync_buttons_to_plot called ===")
    print("Input names:")
    print(names(input))
    print("Plot and table list:")
    str(plot_and_table_list)

    for (suffix in names(plot_and_table_list)) {
        print(paste("Processing suffix:", suffix))
        # Only process pages where data exists - NEVER disable other pages
        if (!is.null(plot_and_table_list[[suffix]])) {
            print(paste("Enabling buttons for", suffix))
            print(paste("Setting redraw button for", suffix))
            set_redraw_button_enabled(input, suffix, TRUE)
            print(paste("Setting share button for", suffix))
            set_share_button_enabled(input, suffix, TRUE)
        } else {
            # Skip disabling buttons for pages that don't have data
            print(paste("Skipping button updates for inactive page:", suffix))
        }
    }
    print("=== sync_buttons_to_plot completed ===")
}
