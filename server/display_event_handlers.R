# server/display_event_handlers.R
source('components/common/button_control.R')

#' Add display event handlers to the application
#' @param session Shiny session object
#' @param input Shiny input object
#' @param output Shiny output object
#' @param plot_state Reactive value for storing plot state
#' @param suffixes Page suffixes to handle (default: c('prerun', 'custom'))
add.display.event.handlers <- function(session, input, output, plot_state, suffixes=c('prerun', 'custom')) {
    #-- General Handler for Running/Redrawing --#
    do.run <- function(suffix, intervention.settings) {
        get.display.size(input, 'prerun')
        
        # Generate new plot and table
        new.plot.and.table <- do.prepare.plot.and.table(
            session = session,
            input = input,
            type = suffix,
            intervention.settings = intervention.settings
        )
        
        if (!is.null(new.plot.and.table)) {
            # Update the state
            current_state <- plot_state()
            current_state[[suffix]] <- new.plot.and.table
            plot_state(current_state)
            
            # Update the UI
            set.display(input, output, suffix, new.plot.and.table)
            sync_buttons_to_plot(input, plot_state())
        }
    }
    
    # Event handlers for prerun
    observeEvent(input$run_prerun, {
        int.settings <- NULL
        do.run(suffix = 'prerun', int.settings)
        simset <- get(load("simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata"))
    })
    
    observeEvent(input$redraw_prerun, {
        current_state <- plot_state()
        do.run(
            suffix = 'prerun',
            intervention.settings = current_state$custom$int.settings
        )
    })
    
    # Event handlers for custom
    observeEvent(input$run_custom, {
        int.settings <- NULL
        do.run(suffix = 'custom', int.settings)
    })
    
    observeEvent(input$redraw_custom, {
        current_state <- plot_state()
        do.run(
            suffix = 'custom',
            intervention.settings = current_state$custom$int.settings
        )
    })
    
    # Initial setup
    session$onFlushed(function() {
        # Initialize display sizes
        js$ping_display_size_onload()
        print("flushed")
        
        js$set_input_value(name = 'left_width_prerun', 
                           value = as.numeric(LEFT.PANEL.SIZE['prerun']))
        js$set_input_value(name = 'right_width_prerun', 
                           value = 0)
        js$set_input_value(name = 'left_width_custom', 
                           value = as.numeric(LEFT.PANEL.SIZE['custom']))
        js$set_input_value(name = 'right_width_custom', 
                           value = 0)
        
        # Sync button states - wrap in observe
        observe({
            sync_buttons_to_plot(input, plot_state())
        })
    }, once = TRUE)
    
    # Resize handler
    handle.resize <- function(suffixes) {
        print("called handle resize")
        current_state <- plot_state()
        lapply(suffixes, function(suffix) {
            display.size <- get.display.size(input, suffix)
            if (!is.null(current_state[[suffix]])) {
                set.display(
                    input = input,
                    output = output,
                    suffix = suffix,
                    plot.and.table = current_state[[suffix]]
                )
            }
        })
    }
    
    # Resize event observers
    observeEvent(input$display_size_prerun, handle.resize('prerun'))
    observeEvent(input$display_size_custom, handle.resize('custom'))
    observeEvent(input$left_width_prerun, handle.resize('prerun'))
    observeEvent(input$right_width_prerun, handle.resize('prerun'))
    observeEvent(input$left_width_custom, handle.resize('custom'))
    observeEvent(input$right_width_custom, handle.resize('custom'))
}