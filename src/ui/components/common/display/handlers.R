# src/ui/components/common/display/handlers.R

#' Initialize display event handlers
#' @param session Shiny session object
#' @param input Shiny input object
#' @param output Shiny output object
#' @param vis_manager Visualization manager instance
#' @param page_id Character: page identifier ('prerun' or 'custom')
initialize_display_handlers <- function(session, input, output, vis_manager, page_id) {
    store <- get_store()

    # Run button handler
    observeEvent(input[[paste0("run_", page_id)]], {
        print(sprintf("Run %s triggered", page_id))
        vis_manager$update_display(input, output, NULL)
    })

    # Redraw button handler
    observeEvent(input[[paste0("redraw_", page_id)]], {
        print(sprintf("Redraw %s triggered", page_id))
        current_state <- store$get_panel_state(page_id)
        vis_manager$update_display(
            input, output,
            intervention_settings = current_state$controls$int.settings
        )
    })

    # Resize handlers
    observeEvent(input[[paste0("display_size_", page_id)]], {
        vis_manager$update_display(input, output, NULL)
    })

    observeEvent(input[[paste0("left_width_", page_id)]], {
        vis_manager$update_display(input, output, NULL)
    })

    observeEvent(input[[paste0("right_width_", page_id)]], {
        vis_manager$update_display(input, output, NULL)
    })
}

#' Initialize common display setup
#' @param session Shiny session object
#' @param input Shiny input object
initialize_display_setup <- function(session, input) {
    session$onFlushed(function() {
        js$ping_display_size_onload()
        print("Session flushed - initializing display sizes")

        # Initialize panel sizes for both pages
        for (page_id in c("prerun", "custom")) {
            js$set_input_value(
                name = paste0("left_width_", page_id),
                value = as.numeric(LEFT.PANEL.SIZE[page_id])
            )
            js$set_input_value(
                name = paste0("right_width_", page_id),
                value = 0
            )
        }
    }, once = TRUE)
}
