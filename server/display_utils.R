# server/display_utils.R

#' Update display with new plot and table
#' @param session Shiny session object
#' @param input Shiny input object
#' @param output Shiny output object
#' @param suffix Page suffix ('prerun' or 'custom')
#' @param intervention.settings Settings for intervention
#' @param plot_state Reactive value for plot state
update_display <- function(session, input, output, suffix, intervention.settings, plot_state) {
    get.display.size(input, suffix)
    
    print("Generating new plot and table")
    new.plot.and.table <- do.prepare.plot.and.table(
        session = session,
        input = input,
        type = suffix,
        intervention.settings = intervention.settings
    )
    
    if (!is.null(new.plot.and.table)) {
        print("Updating display state")
        # Update the state
        current_state <- plot_state()
        current_state[[suffix]] <- new.plot.and.table
        plot_state(current_state)
        
        # Update the UI
        set.display(input, output, suffix, new.plot.and.table)
        sync_buttons_to_plot(input, plot_state())
    }
}