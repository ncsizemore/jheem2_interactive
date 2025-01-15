# components/common/button_control.R

#' Set redraw button enabled state
#' @param input Shiny input object
#' @param suffix Page suffix (prerun or custom)
#' @param enable Boolean to enable/disable button
set_redraw_button_enabled <- function(input, suffix, enable) {
    redraw_id <- paste0("redraw_", suffix)
    if (!is.null(input[[redraw_id]])) {
        shinyjs::toggleState(redraw_id, condition = enable)
    }
}

#' Set share button enabled state
#' @param input Shiny input object
#' @param suffix Page suffix (prerun or custom)
#' @param enable Boolean to enable/disable button
set_share_button_enabled <- function(input, suffix, enable) {
    share_id <- paste0("share_", suffix)
    if (!is.null(input[[share_id]])) {
        shinyjs::toggleState(share_id, condition = enable)
    }
}

#' Sync button states with plot state
#' @param input Shiny input object
#' @param plot_and_table_list List of plot and table data by suffix
sync_buttons_to_plot <- function(input, plot_and_table_list) {
    for (suffix in names(plot_and_table_list)) {
        enable <- !is.null(plot_and_table_list[[suffix]])
        
        set_redraw_button_enabled(input, suffix, enable)
        set_share_button_enabled(input, suffix, enable)
    }
}