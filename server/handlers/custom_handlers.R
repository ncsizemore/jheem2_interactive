# server/handlers/custom_handlers.R

#' Initialize handlers for custom page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_custom_handlers <- function(input, output, session, plot_state) {
  ns <- session$ns # Get namespace function

  # Get configuration
  config <- get_page_complete_config("custom")

  # Create managers
  vis_manager <- create_visualization_manager(session, "custom", ns("visualization"))
  validation_manager <- create_validation_manager(session, "custom", ns("validation"))

  # Handle subgroup count changes
  observeEvent(input$subgroups_count_custom, {
    print(paste("Subgroups count changed:", input$subgroups_count_custom))

    # Create validation boundary with validation manager
    validation_boundary <- create_validation_boundary(
      session,
      output,
      "custom",
      "subgroups_validation",
      validation_manager = validation_manager
    )

    # Get the numeric value, handle empty/NULL
    count <- tryCatch(
      {
        as.numeric(input$subgroups_count_custom)
      },
      warning = function(w) {
        NULL
      },
      error = function(e) {
        NULL
      }
    )

    # Validate subgroups count
    valid_count <- validation_boundary$validate(
      count,
      list(
        validation_boundary$rules$required("Number of subgroups is required"),
        validation_boundary$rules$range(
          min = config$subgroups$min,
          max = config$subgroups$max,
          message = sprintf(
            "Number of subgroups must be between %d and %d",
            config$subgroups$min,
            config$subgroups$max
          )
        )
      ),
      field_id = "subgroups_count_custom" # Add field_id
    )

    # Clear existing panels if invalid
    if (!valid_count) {
      output$subgroup_panels_custom <- renderUI({
        NULL
      })
      # Reset the input to last valid value or min
      updateNumericInput(
        session,
        "subgroups_count_custom",
        value = config$subgroups$min
      )
    } else {
      # Only render subgroup panels if count is valid
      output$subgroup_panels_custom <- renderUI({
        panels <- lapply(1:count, function(i) {
          create_subgroup_panel(i, config)
        })
        do.call(tagList, panels)
      })
    }
  })

  # Create visualization manager with explicit page ID
  vis_manager <- create_visualization_manager(session, "custom", ns("visualization"))

  # Handle toggle buttons
  observeEvent(input[["custom-toggle_plot"]],
    {
      print("\n=== Plot Toggle Event ===")
      print(paste("1. Event triggered at:", Sys.time()))

      store <- get_store()
      tryCatch(
        {
          state <- store$get_panel_state("custom")
          print("2. Current store state:")
          print(state$visualization)
        },
        error = function(e) {
          print("Error getting store state:", e$message)
        }
      )

      # Update both store and UI state
      vis_manager$set_display_type("plot")
      vis_manager$set_visibility("visible")
      updateTextInput(session, "custom-display_type", value = "plot")
      updateTextInput(session, "custom-visualization_state", value = "visible")

      # Update button states - use exact IDs
      removeClass(id = "custom-toggle_table", class = "active", asis = TRUE)
      addClass(id = "custom-toggle_plot", class = "active", asis = TRUE)

      tryCatch(
        {
          state <- store$get_panel_state("custom")
          print("3. Updated store state:")
          print(state$visualization)
        },
        error = function(e) {
          print("Error getting updated store state:", e$message)
        }
      )
    },
    ignoreInit = TRUE
  )

  observeEvent(input[["custom-toggle_table"]],
    {
      print("\n=== Table Toggle Event ===")
      print(paste("1. Event triggered at:", Sys.time()))

      store <- get_store()
      tryCatch(
        {
          state <- store$get_panel_state("custom")
          print("2. Current store state:")
          print(state$visualization)
        },
        error = function(e) {
          print("Error getting store state:", e$message)
        }
      )

      # Update both store and UI state
      vis_manager$set_display_type("table")
      vis_manager$set_visibility("visible")
      updateTextInput(session, "custom-display_type", value = "table")
      updateTextInput(session, "custom-visualization_state", value = "visible")

      # Update button states - use exact IDs
      removeClass(id = "custom-toggle_plot", class = "active", asis = TRUE)
      addClass(id = "custom-toggle_table", class = "active", asis = TRUE)

      tryCatch(
        {
          state <- store$get_panel_state("custom")
          print("3. Updated store state:")
          print(state$visualization)
        },
        error = function(e) {
          print("Error getting updated store state:", e$message)
        }
      )
    },
    ignoreInit = TRUE
  )

  # Store validation state
  validation_state <- reactiveVal(list())

  # Create observers for intervention inputs
  observe({
    # Get current subgroup count, handle NA/invalid values
    subgroup_count <- tryCatch(
      {
        count <- as.numeric(input$subgroups_count_custom)
        if (is.na(count) || count < config$subgroups$min || count > config$subgroups$max) {
          config$subgroups$min # Default to min if invalid
        } else {
          count
        }
      },
      error = function(e) {
        config$subgroups$min # Default to min on error
      }
    )

    # For each subgroup
    for (i in 1:subgroup_count) {
      local({
        group_num <- i # Need local binding

        # For each intervention component in config
        for (component_name in names(config$interventions$components)) {
          local({
            component <- config$interventions$components[[component_name]]

            # Skip if not a compound type with numeric/select inputs
            if (component$type != "compound") {
              return()
            }

            enabled_id <- paste0("int_", component_name, "_", group_num, "_custom_enabled")

            # For each input in the compound component
            for (input_name in names(component$inputs)) {
              input_config <- component$inputs[[input_name]]
              if (input_name == "enabled") next # Skip enabled checkbox

              value_id <- paste0("int_", component_name, "_", group_num, "_custom_", input_name)

              # Add input change observer
              observeEvent(input[[enabled_id]], {
                if (!input[[enabled_id]]) {
                  # Clear validation state for this field
                  validation_manager$update_field(value_id, TRUE)
                  # Clear UI validation state
                  runjs(sprintf("
                      $('#%s').removeClass('is-invalid');
                      $('#%s_error').hide();
                  ", value_id, value_id))
                }
              })

              observeEvent(input[[value_id]], {
                if (input[[enabled_id]]) {
                  validation_boundary <- create_validation_boundary(
                    session,
                    output,
                    "custom",
                    paste0(component_name, "_validation_", group_num),
                    validation_manager = validation_manager
                  )

                  # Create validation rules based on input type
                  rules <- list(
                    validation_boundary$rules$required(
                      sprintf("%s is required", input_config$label)
                    )
                  )

                  if (input_config$type == "numeric") {
                    rules[[length(rules) + 1]] <- validation_boundary$rules$range(
                      min = input_config$min,
                      max = input_config$max,
                      message = sprintf(
                        "%s must be between %s and %s",
                        input_config$label,
                        input_config$min,
                        input_config$max
                      )
                    )
                  }

                  # Validate and update UI
                  valid <- validation_boundary$validate(input[[value_id]], rules, field_id = value_id)
                  if (!valid) {
                    error_state <- validation_manager$get_field_state(value_id)
                    runjs(sprintf("
                      $('#%s').addClass('is-invalid');
                      $('#%s_error').text('%s').show();
                    ", value_id, value_id, error_state$message))
                  } else {
                    runjs(sprintf("
                      $('#%s').removeClass('is-invalid');
                      $('#%s_error').hide();
                    ", value_id, value_id))
                  }
                }
              })
            }
          })
        }
      })
    }
  })

  # Modify generate button handler
  observeEvent(input$generate_custom, {
    print("Generate button pressed (custom)")

    # Check all validations, but only for enabled interventions
    validation_results <- validation_manager$is_valid()

    if (validate_custom_inputs(session, output, input, config) && validation_results) {
      # Get subgroup count and settings
      subgroup_count <- isolate(input$subgroups_count_custom)
      settings <- collect_custom_settings(input, subgroup_count)

      # Update visualization state
      updateTextInput(session, ns("custom-visualization_state"), value = "visible")

      # Call update_display with settings and simset
      update_display(session, input, output, "custom", settings, plot_state)

      showNotification(
        "Custom projections starting...",
        type = "message"
      )
    } else {
      showNotification(
        "Please correct the highlighted errors before proceeding.",
        type = "error"
      )
    }
  })
}


validate_custom_inputs <- function(session, output, input, config) {
  location <- isolate(input$int_location_custom)

  if (is.null(location) || location == "none") {
    showNotification(
      "Please select a location first",
      type = "warning"
    )
    return(FALSE)
  }
  return(TRUE)
}

collect_custom_settings <- function(input, subgroup_count) {
  print("Collecting custom settings")

  # Get plot control settings
  plot_settings <- get_control_settings(input, "custom")
  print("Plot settings:")
  str(plot_settings)

  # Get intervention settings
  intervention_settings <- list(
    location = isolate(input$int_location_custom),
    subgroups = lapply(1:subgroup_count, function(i) {
      collect_subgroup_settings(input, i)
    })
  )
  print("Intervention settings:")
  str(intervention_settings)

  # Combine both types of settings
  c(plot_settings, intervention_settings)
}

collect_subgroup_settings <- function(input, group_num) {
  list(
    demographics = list(
      age_groups = isolate(input[[paste0("int_age_groups_", group_num, "_custom")]]),
      race_ethnicity = isolate(input[[paste0("int_race_ethnicity_", group_num, "_custom")]]),
      biological_sex = isolate(input[[paste0("int_biological_sex_", group_num, "_custom")]]),
      risk_factor = isolate(input[[paste0("int_risk_factor_", group_num, "_custom")]])
    ),
    interventions = list(
      dates = list(
        start = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_start")]]),
        end = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_end")]])
      ),
      testing = if (isolate(input[[paste0("int_testing_", group_num, "_custom_enabled")]])) {
        list(frequency = isolate(input[[paste0("int_testing_", group_num, "_custom_frequency")]]))
      },
      prep = if (isolate(input[[paste0("int_prep_", group_num, "_custom_enabled")]])) {
        list(coverage = isolate(input[[paste0("int_prep_", group_num, "_custom_coverage")]]))
      },
      suppression = if (isolate(input[[paste0("int_suppression_", group_num, "_custom_enabled")]])) {
        list(proportion = isolate(input[[paste0("int_suppression_", group_num, "_custom_proportion")]]))
      }
    )
  )
}
