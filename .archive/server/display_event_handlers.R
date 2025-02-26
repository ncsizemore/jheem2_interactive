# server/display_event_handlers.R
source('components/common/button_control.R')
source('server/display_utils.R')

#' Add display event handlers to the application
#' @param session Shiny session object
#' @param input Shiny input object
#' @param output Shiny output object
#' @param plot_state Reactive value for storing plot state
#' @param suffixes Page suffixes to handle (default: c('prerun', 'custom'))
add.display.event.handlers <- function(session, input, output, plot_state, suffixes=c('prerun', 'custom')) {
    
    # Event handlers for prerun
    observeEvent(input$run_prerun, {
        print("Run prerun triggered")
        int.settings <- NULL
        update_display(session, input, output, 'prerun', int.settings, plot_state)
    })
    
    observeEvent(input$redraw_prerun, {
        print("Redraw prerun triggered")
        current_state <- plot_state()
        update_display(
            session, input, output,
            'prerun',
            intervention.settings = current_state$custom$int.settings,
            plot_state
        )
    })
    
    # Event handlers for custom
    observeEvent(input$run_custom, {
        print("Run custom triggered")
        int.settings <- NULL
        update_display(session, input, output, 'custom', int.settings, plot_state)
    })
    
    observeEvent(input$redraw_custom, {
        print("Redraw custom triggered")
        current_state <- plot_state()
        update_display(
            session, input, output,
            'custom',
            intervention.settings = current_state$custom$int.settings,
            plot_state
        )
    })
    
    # Initial setup
    session$onFlushed(function() {
        js$ping_display_size_onload()
        print("Session flushed - initializing display sizes")
        
        js$set_input_value(name = 'left_width_prerun', 
                           value = as.numeric(LEFT.PANEL.SIZE['prerun']))
        js$set_input_value(name = 'right_width_prerun', 
                           value = 0)
        js$set_input_value(name = 'left_width_custom', 
                           value = as.numeric(LEFT.PANEL.SIZE['custom']))
        js$set_input_value(name = 'right_width_custom', 
                           value = 0)
        
        # Sync button states
        observe({
            sync_buttons_to_plot(input, plot_state())
        })
    }, once = TRUE)
    
    # Resize handlers
    observeEvent(input$display_size_prerun, {
        update_display(session, input, output, 'prerun', NULL, plot_state)
    })
    observeEvent(input$display_size_custom, {
        update_display(session, input, output, 'custom', NULL, plot_state)
    })
    observeEvent(input$left_width_prerun, {
        update_display(session, input, output, 'prerun', NULL, plot_state)
    })
    observeEvent(input$right_width_prerun, {
        update_display(session, input, output, 'prerun', NULL, plot_state)
    })
    observeEvent(input$left_width_custom, {
        update_display(session, input, output, 'custom', NULL, plot_state)
    })
    observeEvent(input$right_width_custom, {
        update_display(session, input, output, 'custom', NULL, plot_state)
    })
}