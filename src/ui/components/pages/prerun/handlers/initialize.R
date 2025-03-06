# src/ui/components/pages/prerun/handlers/initialize.R

#' Initialize handlers for prerun page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_prerun_handlers <- function(input, output, session, plot_state) {
    ns <- session$ns

    # Get configuration
    config <- get_page_complete_config("prerun")

    # Create managers
    vis_manager <- create_visualization_manager(session, "prerun", ns("visualization"))

    # Initialize handlers
    initialize_prerun_visualization_handlers(input, output, session, vis_manager)

    # Create managers
    validation_manager <- create_validation_manager(session, "prerun", ns("validation"))

    # Store validation manager in session for access by other functions
    session$userData$validation_manager <- validation_manager

    # Initialize display handlers
    initialize_display_handlers(session, input, output, vis_manager, "prerun")
    initialize_display_setup(session, input)

    # initialize_intervention_handlers(input, output, session, validation_manager, config)

    # Validate location selection
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "prerun",
        "location_validation",
        validation_manager = validation_manager
    )

    # Setup validation observers for each selector in the config
    config <- get_page_complete_config("prerun")
    selector_ids <- c("location", names(config$selectors))
    
    # Deduplicate in case location is also in the selectors
    selector_ids <- unique(selector_ids)
    
    # Create observer for each selector
    for (selector_id in selector_ids) {
        local({
            local_selector_id <- selector_id  # Create local copy for closure
            input_id <- paste0("int_", local_selector_id, "_prerun")
            
            # Human-readable name for validation messages
            selector_name <- if (local_selector_id == "location") {
                "location"
            } else if (!is.null(config$selectors[[local_selector_id]]$label)) {
                # Use label from config if available
                tolower(config$selectors[[local_selector_id]]$label)
            } else {
                # Fallback to selector ID with spaces
                gsub("_", " ", local_selector_id)
            }
            
            # Create the observer - the input existence check happens inside the reactive context
            observeEvent(input[[input_id]], {
                print(paste(selector_name, "selected:", input[[input_id]]))
                
                validation_boundary$validate(
                    input[[input_id]],
                    list(
                        validation_boundary$rules$required(paste("Please select a", selector_name)),
                        validation_boundary$rules$custom(
                            test_fn = function(value) !is.null(value) && value != "none",
                            message = paste("Please select a", selector_name)
                        )
                    ),
                    field_id = input_id
                )
                
                # Special handling for location selection
                if (local_selector_id == "location" && input[[input_id]] == "none") {
                    # Reset downstream selections if needed
                    # This would need to be configured based on dependencies
                }
            }, ignoreNULL = FALSE, ignoreInit = FALSE)
        })
    }

    # Handle generate button
    observeEvent(input$generate_projections_prerun, {
        print("[PRERUN] === Generate Button Event ===")

        # Check all validations
        print("[PRERUN] 1. Checking validations...")
        validation_results <- validation_manager$is_valid()

        if (validation_results) {
            print("[PRERUN] 2. Collecting settings...")
            settings <- collect_prerun_settings(input)
            print("[PRERUN] Settings collected:")
            str(settings)

            print("[PRERUN] 3. Updating visibility...")
            vis_manager$set_visibility("visible")

            print("[PRERUN] 4. Calling update_display...")
            vis_manager$update_display(input, output, settings)
        } else {
            showNotification(
                "Please select a location and intervention settings first",
                type = "warning"
            )
        }
    })
}

#' Collect settings for prerun page
#' @param input Shiny input object
#' @return List of settings
collect_prerun_settings <- function(input) {
    print("Collecting prerun settings:")
    
    # Get page config to determine which fields to collect
    config <- get_page_complete_config("prerun")
    
    # Build settings based on selectors in config
    settings <- list()
    
    # Always include location as it's a core requirement
    settings$location <- isolate(input$int_location_prerun)
    
    # Add all selectors defined in the config
    for (selector_id in names(config$selectors)) {
        input_id <- paste0("int_", selector_id, "_prerun")
        # Use tryCatch to handle non-existent inputs gracefully
        tryCatch({
            settings[[selector_id]] <- isolate(input[[input_id]])
        }, error = function(e) {
            # Print warning but continue
            print(paste("Warning: Could not collect setting for", selector_id, ":", e$message))
        })
    }
    
    print("Settings collected:")
    print(settings)
    settings
}
