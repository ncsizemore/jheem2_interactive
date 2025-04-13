# src/ui/components/common/display/plot_panel.R

source("src/data/loaders/baseline_loader.R")
source("src/ui/components/common/display/plot_customizer.R")

parse_template <- function(template, values) {
  if (is.null(template) || length(template) == 0) {
    return(template)
  }
  result <- template
  for (name in names(values)) {
    if (!is.null(values[[name]])) {
      pattern <- paste0("\\{", name, "\\}")
      result <- gsub(pattern, values[[name]], result)
    }
  }
  return(result)
}

create_style_manager_from_config <- function(vis_config) {
  default_style_manager <- tryCatch(get.default.style.manager(), error = function(e) {
    warning("Default style manager error: ", e$message)
    NULL
  })

  if (is.null(vis_config) || is.null(vis_config$style_manager)) {
    return(default_style_manager)
  }

  style_config <- vis_config$style_manager
  params <- list(color.sim.by = "simset", linetype.sim.by = "stratum")

  if (!is.null(style_config$general)) {
    for (param_name in names(style_config$general)) {
      params[[param_name]] <- style_config$general[[param_name]]
    }
  }

  if (!is.null(style_config$intervention$color) && !is.null(style_config$baseline$color)) {
    custom_palette <- function(n) {
      pal_jama_safe <- tryCatch(ggsci::pal_jama(), error = function(e) scales::hue_pal())
      if (n <= 2) {
        return(c(style_config$intervention$color, style_config$baseline$color))
      } else {
        c(style_config$intervention$color, style_config$baseline$color, pal_jama_safe(n - 2))
      }
    }
    params$sim.palette <- custom_palette
  }

  if (!is.null(style_config$use_different_line_types)) {
    if (style_config$use_different_line_types) {
      params$linetype.sim.by <- "simset"
    } else {
      if (!("linetype.sim.by" %in% names(style_config$general))) {
        params$linetype.sim.by <- "stratum"
      }
    }
  }

  if (exists("create.style.manager") && is.function(create.style.manager)) {
    do.call(create.style.manager, params)
  } else {
    warning("create.style.manager not found.")
    default_style_manager
  }
}

create_plot_panel <- function(id, type = "static") {
  ns <- NS(id)

  tags$div(
    class = paste0("main-panel main-panel-plot ", id, "-plot-panel"),
    tags$input(id = ns("visualization_state"), type = "hidden", value = "hidden"),
    tags$input(id = ns("display_type"), type = "hidden", value = "plot"),
    conditionalPanel(
      condition = sprintf(
        "input['%s'] === 'visible' && input['%s'] === 'plot'",
        ns("visualization_state"),
        ns("display_type")
      ),
      tags$div(
        class = "panel-container",
        tags$div(
          class = "panel-content",
          plotOutput(
            ns("mainPlot"),
            height = "600px",
            width = "100%"
          ),
          # Remove conditionalPanel, use shinyjs::show/hide instead
          # Give the indicator div a specific ID for shinyjs targeting
          tags$div(
            id = ns("loading_indicator"), # Added ID
            class = "loading-indicator",
            style = "display: none;", # Start hidden
            tags$div(
              class = "loading-content",
              tags$span(class = "loading-spinner"),
              tags$span("Generating plot...")
            )
          ), # Added comma back
          # Keep the hidden input for plot_status, other logic might use it
          tags$div(
            class = "hidden",
            textInput(ns("plot_status"), label = NULL, value = "ready")
          )
        )
      )
    ),
    tags$div(
      class = "plot-error error",
      textOutput(ns("plot_error_message"), inline = FALSE)
    ),
    uiOutput(ns("error_display"))
  )
}

plot_panel_server <- function(id, settings) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    store <- get_store()
    req(store)

    direct_error_message <- reactiveVal(NULL)
    output$plot_error_message <- renderText({
      direct_error_message()
    })

    vis_manager <- create_visualization_manager(session, id, ns("visualization"))
    control_manager <- create_control_manager(session, id, ns("controls"), settings) # Uses new stateless manager

    validation_boundary <- create_validation_boundary(
      session, output, id, "validation",
      state_manager = vis_manager
    )
    plot_boundary <- create_plot_boundary(
      session, output, id, "plot",
      state_manager = vis_manager
    )
    sim_boundary <- create_simulation_boundary(
      session, output, id, "simulation",
      state_manager = vis_manager
    )

    # Define reactive dependencies for cache key *outside* renderPlot
    current_settings_reactive <- reactive({
      control_manager$get_settings()
    })
    current_sim_id_reactive <- reactive({
      store$get_current_simulation_id(id)
    })

    # Wrap renderPlot with bindCache for performance
    # Cache key reactives are defined above
    output$mainPlot <- bindCache( # Apply bindCache *around* renderPlot
      renderPlot(
        {
          # Initial UI state checks
          req(input$visualization_state == "visible", cancelOutput = TRUE)
          req(input$display_type == "plot", cancelOutput = TRUE)

          # Use the reactive values defined outside for this render execution
          # These also serve as dependencies for the renderPlot itself
          current_settings <- current_settings_reactive()
          current_sim_id <- current_sim_id_reactive()

          # Validate settings and sim ID
          req(current_settings, !is.null(current_settings$outcomes), cancelOutput = TRUE)
          req(!is.null(current_sim_id), cancelOutput = TRUE)

          # print(paste0("-[ renderPlot", id, " ]- Running with SimID: ", current_sim_id)) # Commented out
          # print(paste0(
          #   "-[ renderPlot", id, " ]- Using settings: O=", paste(current_settings$outcomes, collapse = ", "),
          #   ", F=", paste(current_settings$facet.by, collapse = ", "),
          #   ", S=", current_settings$summary.type
          # )) # Commented out

          # Wrap the actual plot generation in isolate to prevent unwanted internal dependencies
          generated_plot <- isolate({
            # Set status - won't create unwanted dependencies because it uses a separate reactiveVal
            store$set_plot_status(id, "loading")

            # Get current simulation and check for errors
            sim_state_check <- store$get_simulation(current_sim_id)

            if (is.null(sim_state_check) || sim_state_check$status == "error") {
              err_msg <- if (is.null(sim_state_check)) "No sim" else sim_state_check$error_message %||% "Sim error"
              # print(paste0("-[ renderPlot", id, " ]- Sim Error: ", err_msg)) # Keep print for actual error

              sim_boundary$set_error(
                message = err_msg,
                type = ERROR_TYPES$SIMULATION,
                severity = SEVERITY_LEVELS$ERROR
              )
              store$set_plot_status(id, "error")

              direct_error_message(paste("Error:", err_msg))
              return(NULL)
            }

            # Get simulation data
            sim_state_data <- store$get_current_simulation_data(id)

            if (is.null(sim_state_data) || is.null(sim_state_data$simset)) {
              err_msg <- "No sim data."
              # print(paste0("-[ renderPlot", id, " ]- Data Error: ", err_msg)) # Keep print for actual error

              plot_boundary$set_error(
                message = err_msg,
                type = ERROR_TYPES$PLOT,
                severity = SEVERITY_LEVELS$ERROR
              )
              store$set_plot_status(id, "error")

              direct_error_message(paste("Error:", err_msg))
              return(NULL)
            }

            # Generate the plot
            generated_plot <- tryCatch(
              {
                sim_settings <- sim_state_check$settings
                req(sim_settings)

                vis_config <- tryCatch(get_component_config("visualization"), error = function(e) NULL)

                req(
                  exists("load_baseline_simulation") && is.function(load_baseline_simulation),
                  exists("create_style_manager_from_config") && is.function(create_style_manager_from_config),
                  exists("customize_plot_from_config") && is.function(customize_plot_from_config),
                  exists("simplot") && is.function(simplot)
                )

                # Get baseline simulation if applicable
                baseline_simset <- NULL
                if (id == "custom") {
                  baseline_simset <- store$get_original_base_simulation(id)
                }

                if (is.null(baseline_simset)) {
                  baseline_simset <- tryCatch(load_baseline_simulation(id, sim_settings), error = function(e) NULL)
                }

                # Set up plot arguments
                plot_args <- list(
                  outcomes = current_settings$outcomes,
                  facet.by = current_settings$facet.by,
                  summary.type = current_settings$summary.type
                )

                style_manager <- create_style_manager_from_config(vis_config)
                if (!is.null(style_manager)) {
                  plot_args$style.manager <- style_manager
                }

                # Create the plot
                the_plot <- NULL

                if (!is.null(baseline_simset)) {
                  # Use both baseline and intervention simsets
                  location_val <- sim_settings$location %||% "Current"
                  template_values <- list(location = location_val)

                  baseline_label <- "Baseline"
                  intervention_label <- "Intervention"

                  if (!is.null(vis_config$baseline_simulations)) {
                    baseline_label <- vis_config$baseline_simulations$default_label %||% baseline_label
                    intervention_label_template <- vis_config$baseline_simulations$intervention_label %||% "Intervention ({location})"

                    if (exists("parse_template")) {
                      baseline_label <- parse_template(baseline_label, template_values)
                      intervention_label <- parse_template(intervention_label_template, template_values)
                    }
                  }

                  sim_list <- list()
                  sim_list[[baseline_label]] <- baseline_simset
                  sim_list[[intervention_label]] <- sim_state_data$simset

                  the_plot <- do.call(simplot, c(sim_list, plot_args))
                } else {
                  # Use just the intervention simset
                  the_plot <- do.call(simplot, c(list(sim_state_data$simset), plot_args))
                }

                req(the_plot)

                # Apply customizations
                the_plot <- customize_plot_from_config(the_plot, vis_config)
                req(the_plot)

                # print(paste0("-[ renderPlot", id, " ]- Plot generated.")) # Commented out

                # Clear any errors and update status
                sim_boundary$clear()
                plot_boundary$clear()
                validation_boundary$clear()
                store$clear_page_error_state(id)
                store$set_plot_status(id, "ready")

                direct_error_message(NULL)

                # Return the plot
                the_plot
              },
              error = function(e) {
                err_msg <- conditionMessage(e)
                # print(paste0("-[ renderPlot", id, " ]- Plot Error: ", err_msg)) # Keep print for actual error

                plot_boundary$set_error(
                  message = err_msg,
                  type = ERROR_TYPES$PLOT,
                  severity = SEVERITY_LEVELS$ERROR
                )
                store$update_page_error_state(
                  id,
                  has_error = TRUE,
                  message = err_msg,
                  type = ERROR_TYPES$PLOT,
                  severity = SEVERITY_LEVELS$ERROR
                )
                store$set_plot_status(id, "error")

                direct_error_message(paste("Error:", err_msg))
                NULL
              }
            )

            return(generated_plot)
          }) # End isolate

          return(generated_plot)
        },
        res = 96
      ), # End renderPlot expression
      # Cache key arguments for bindCache:
      id,
      current_settings_reactive(),
      current_sim_id_reactive()
    ) # End bindCache

    # --- Visibility Observer (Handles Reset Only) ---
    observeEvent(list(input$visualization_state, input$display_type),
      {
        state <- input$visualization_state
        display <- input$display_type
        id_log_prefix <- paste0("-[ PlotVisDisp", id, " ]-")
        panel_type <- "plot"

        if (!(state == "visible" && display == panel_type)) {
          if (!is.null(isolate(direct_error_message())) ||
            isolate(store$get_plot_status(id) == "loading")) {
            # print(paste0(id_log_prefix, " Deactivating. Resetting local state...")) # Commented out
            isolate({
              vis_manager$reset()
              validation_boundary$clear()
              plot_boundary$clear()
              sim_boundary$clear()
              direct_error_message(NULL)
              store$set_plot_status(id, "ready")
            })
          }
        } else {
          # print(paste0(id_log_prefix, " State is active. renderPlot will run.")) # Commented out
          isolate(direct_error_message(NULL))
        }
      },
      ignoreNULL = TRUE,
      ignoreInit = TRUE
    )

    # --- Button Observer (Updates control_manager ONLY) ---
    observeEvent(input$update_visualization, {
      req(input$update_visualization > 0)
      req(input$visualization_state == "visible")
      req(input$display_type == "plot")

      # print(paste0("-[ PlotButton", id, " ]- Clicked.")) # Commented out

      new_settings <- isolate({
        outcomes <- input[[paste0("outcomes_", id)]]
        facet_by_in <- input[[paste0("facet_by_", id)]]
        summary_type <- input[[paste0("summary_type_", id)]]

        valid <- TRUE

        if (is.null(outcomes) || length(outcomes) == 0 || all(outcomes == "")) {
          showNotification("Select outcome.", type = "warning")
          valid <- FALSE
        }

        if (is.null(summary_type) || summary_type == "") {
          showNotification("Select summary.", type = "warning")
          valid <- FALSE
        }

        if (!valid) {
          return(NULL)
        }

        facet_value <- if (!is.null(facet_by_in) &&
          length(facet_by_in) > 0 &&
          !all(facet_by_in == "")) {
          as.character(facet_by_in)
        } else {
          NULL
        }

        list(
          outcomes = as.character(outcomes),
          facet.by = facet_value,
          summary.type = summary_type
        )
      })

      if (!is.null(new_settings)) {
        # print(paste0("-[ PlotButton", id, " ]- Updating control_manager ONLY...")) # Commented out
        # str(new_settings) # Commented out
        control_manager$update_settings(new_settings)
      } else {
        # print(paste0("-[ PlotButton", id, " ]- Settings validation failed.")) # Commented out
      }
    })

    # --- Error handling & Debug observers ---
    observe({
      sim_id <- isolate(store$get_current_simulation_id(id))
      sim_state <- if (!is.null(sim_id)) isolate(store$get_simulation(sim_id)) else NULL

      isolate({
        if (!is.null(sim_state) &&
          sim_state$status == "error" &&
          !is.null(sim_state$error_message)) {
          err_msg <- sprintf("Error: %s", as.character(sim_state$error_message))

          if (is.null(direct_error_message()) || direct_error_message() != err_msg) {
            # print(paste0("-[ PlotSimObserver", id, " ]- Sim error: ", err_msg)) # Keep print for actual error

            sim_boundary$set_error(
              message = sim_state$error_message,
              type = ERROR_TYPES$SIMULATION,
              severity = SEVERITY_LEVELS$ERROR
            )

            direct_error_message(err_msg)
            store$set_plot_status(id, "error")
          }
        }
      })
    })

    observe({
      page_error_state <- isolate(store$get_page_error_state(id))

      isolate({
        if (page_error_state$has_error && !is.null(page_error_state$message)) {
          err_msg <- sprintf("Error: %s", page_error_state$message)

          if (is.null(direct_error_message()) || direct_error_message() != err_msg) {
            # print(paste0("-[ PlotPersistObserver", id, " ]- Syncing global error: ", err_msg)) # Keep print for actual error

            error_type <- page_error_state$type %||% ERROR_TYPES$SIMULATION
            boundary_to_use <- switch(error_type,
              SIMULATION = sim_boundary,
              PLOT = plot_boundary,
              VALIDATION = validation_boundary,
              sim_boundary
            )

            if (!is.null(boundary_to_use)) {
              boundary_to_use$set_error(
                message = page_error_state$message,
                type = error_type,
                severity = page_error_state$severity %||% SEVERITY_LEVELS$ERROR
              )
            }

            direct_error_message(err_msg)
            store$set_plot_status(id, "error")
          }
        }
      })
    })

    last_error_state <- reactiveVal(list(has_error = FALSE, message = NULL))

    observe({
      error_state <- if (!is.null(sim_boundary)) isolate(sim_boundary$get_state()) else NULL
      error_visible <- !is.null(error_state) && error_state$has_error

      current_direct_error <- direct_error_message()
      has_direct_error <- !is.null(current_direct_error) && nzchar(current_direct_error)

      current <- list(
        has_error = error_visible,
        message = if (error_visible) error_state$message else NULL,
        direct_error = has_direct_error
      )

      prev <- last_error_state()

      if (!identical(current, prev)) {
        if (error_visible || has_direct_error) {
          print(sprintf(
            "[DEBUG_PLOT][%s] Error boundary:%s Direct:%s",
            id,
            if (error_visible) "VISIBLE" else "HIDDEN",
            if (has_direct_error) "VISIBLE" else "HIDDEN"
          ))
        }

        last_error_state(current)
      }
    })
  }) # END moduleServer
}
