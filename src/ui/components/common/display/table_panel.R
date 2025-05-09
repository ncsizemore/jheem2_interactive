# src/ui/components/common/display/table_panel.R

source("src/data/loaders/baseline_loader.R")

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

create_table_panel <- function(id) {
    ns <- NS(id)

    tags$div(
        class = paste0("main-panel main-panel-table ", id, "-table-panel"),
        tags$input(id = ns("visualization_state"), type = "hidden", value = "hidden"),
        tags$input(id = ns("display_type"), type = "hidden", value = "plot"),
        conditionalPanel(
            condition = sprintf(
                "input['%s'] === 'visible' && input['%s'] === 'table'",
                ns("visualization_state"),
                ns("display_type")
            ),
            tags$div(
                class = "panel-container panel-section", # Added panel-section for card styling
                tags$div(
                    class = "panel-content",
                    tags$div(
                        style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;", # Added margin-bottom
                        tags$h5("Data Table"), # Example title, can be made dynamic or removed
                        downloadButton(ns("downloadTable"), label = NULL, title = "Download Table Data (CSV)", class = "btn-jheem-primary")
                    ),
                    tableOutput(ns("mainTable")),
                    tags$div(
                        class = "pagination-controls",
                        tags$div(
                            class = "pagination-container",
                            tags$div(
                                class = "rows-per-page",
                                tags$label(`for` = ns("page_size"), "Rows per page:"),
                                tags$select(
                                    id = ns("page_size"),
                                    class = "page-size-select",
                                    tags$option("50", value = "50", selected = TRUE),
                                    tags$option("100", value = "100"),
                                    tags$option("200", value = "200")
                                )
                            ),
                            tags$div(
                                class = "pagination-navigation",
                                actionButton(ns("prev_page"), "Previous", class = "btn-pagination"),
                                tags$span(class = "page-info", textOutput(ns("page_info"), inline = TRUE)),
                                actionButton(ns("next_page"), "Next", class = "btn-pagination")
                            )
                        )
                    ),
                    conditionalPanel(
                        condition = sprintf("input['%s'] === 'loading'", ns("plot_status")),
                        tags$div(
                            class = "loading-indicator",
                            tags$div(
                                class = "loading-content",
                                tags$span(class = "loading-spinner"),
                                tags$span("Generating table...")
                            )
                        )
                    ),
                    tags$div(
                        class = "hidden",
                        textInput(ns("plot_status"), label = NULL, value = "ready")
                    )
                )
            )
        ),
        tags$div(
            class = "plot-error error table-error",
            textOutput(ns("table_error_message"), inline = FALSE)
        ),
        uiOutput(ns("error_display"))
    )
}

table_panel_server <- function(id, settings) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns
        store <- get_store()
        req(store)

        direct_table_error_message <- reactiveVal(NULL)
        current_page <- reactiveVal(1)
        total_rows_in_data <- reactiveVal(0)

        output$table_error_message <- renderText({
            direct_table_error_message()
        })

        vis_manager <- create_visualization_manager(session, id, ns("visualization"))
        control_manager <- create_control_manager(session, id, ns("controls"), settings) # Uses new stateless manager

        validation_boundary <- create_validation_boundary(
            session, output, id, "validation",
            state_manager = vis_manager
        )
        sim_boundary <- create_simulation_boundary(
            session, output, id, "simulation",
            state_manager = vis_manager
        )

        # Define reactive dependencies for cache key *outside* the main reactive
        current_settings_reactive <- reactive({
            control_manager$get_settings()
        })
        current_sim_id_reactive <- reactive({
            store$get_current_simulation_id(id)
        })

        # --- Reactive expression for generating the FULL dataset ---
        # Depends ONLY on control_manager settings (which change on button press)
        # AND the current simulation ID (which changes when a new simulation is generated)
        # Apply bindCache *around* the reactive expression
        full_formatted_data <- bindCache(
            reactive({
                # Use the reactive values defined outside for this execution
                # These also serve as dependencies for this reactive itself
                current_settings <- current_settings_reactive()
                current_sim_id <- current_sim_id_reactive()
                req(current_settings, !is.null(current_settings$outcomes), cancelOutput = TRUE) # Require valid settings

                # Check visibility/type here as well
                req(input$visualization_state == "visible", cancelOutput = TRUE)
                req(input$display_type == "table", cancelOutput = TRUE)

                # Require a sim ID if rendering shouldn't happen without one
                req(!is.null(current_sim_id), cancelOutput = TRUE)

                print(paste0("-[ Reactive full_formatted_data", id, " ]- Running DATA GENERATION. SimID: ", current_sim_id))
                print(paste0(
                    "-[ Reactive full_formatted_data", id, " ]- Using settings: O=",
                    paste(current_settings$outcomes, collapse = ", "),
                    ", F=", paste(current_settings$facet.by, collapse = ", "),
                    ", S=", current_settings$summary.type
                ))

                # --- Isolate the actual data generation ---
                data_result <- isolate({
                    # Set loading status without creating unwanted dependencies
                    store$set_plot_status(id, "loading")

                    # Sim/Data Checks
                    sim_state_check <- store$get_simulation(current_sim_id)

                    if (is.null(sim_state_check) || sim_state_check$status == "error") {
                        err_msg <- if (is.null(sim_state_check)) "No sim" else sim_state_check$error_message %||% "Sim error"
                        print(paste0("-[ Reactive full_formatted_data", id, " ]- Sim Error: ", err_msg))

                        sim_boundary$set_error(
                            message = err_msg,
                            type = ERROR_TYPES$SIMULATION,
                            severity = SEVERITY_LEVELS$ERROR
                        )
                        store$set_plot_status(id, "error")

                        direct_table_error_message(paste("Error:", err_msg))
                        return(NULL) # Return NULL inside isolate
                    }

                    sim_state_data <- store$get_current_simulation_data(id)

                    if (is.null(sim_state_data) || is.null(sim_state_data$simset)) {
                        err_msg <- "No sim data."
                        print(paste0("-[ Reactive full_formatted_data", id, " ]- Data Error: ", err_msg))

                        sim_boundary$set_error(
                            message = err_msg,
                            type = ERROR_TYPES$DATA,
                            severity = SEVERITY_LEVELS$ERROR
                        )
                        store$set_plot_status(id, "error")

                        direct_table_error_message(paste("Error:", err_msg))
                        return(NULL)
                    }

                    # Generate FULL formatted data
                    fdata <- tryCatch(
                        {
                            sim_settings <- sim_state_check$settings
                            req(sim_settings)

                            vis_config <- tryCatch(get_component_config("visualization"), error = function(e) NULL)

                            req(
                                exists("load_baseline_simulation") && is.function(load_baseline_simulation),
                                exists("transform_simulation_data") && is.function(transform_simulation_data),
                                exists("format_table_data") && is.function(format_table_data)
                            )

                            baseline_simset <- NULL
                            if (id == "custom") {
                                baseline_simset <- store$get_original_base_simulation(id)
                            }

                            if (is.null(baseline_simset)) {
                                baseline_simset <- tryCatch(load_baseline_simulation(id, sim_settings), error = function(e) NULL)
                            }

                            data_source <- NULL

                            if (!is.null(baseline_simset)) {
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

                                data_source <- list()
                                data_source[[baseline_label]] <- baseline_simset
                                data_source[[intervention_label]] <- sim_state_data$simset
                            } else {
                                data_source <- sim_state_data$simset
                            }

                            transformed_data <- transform_simulation_data(data_source, current_settings)
                            formatted <- format_table_data(transformed_data, get_component_config("controls"))

                            print(paste0("-[ Reactive full_formatted_data", id, " ]- Full data generated. Rows: ", nrow(formatted)))

                            # Clear any errors and update status
                            sim_boundary$clear()
                            validation_boundary$clear()
                            store$clear_page_error_state(id)
                            store$set_plot_status(id, "ready")

                            direct_table_error_message(NULL)
                            formatted
                        },
                        error = function(e) {
                            err_msg <- conditionMessage(e)
                            print(paste0("-[ Reactive full_formatted_data", id, " ]- Data Gen Error: ", err_msg))

                            sim_boundary$set_error(
                                message = err_msg,
                                type = ERROR_TYPES$DATA,
                                severity = SEVERITY_LEVELS$ERROR
                            )
                            store$update_page_error_state(
                                id,
                                has_error = TRUE,
                                message = err_msg,
                                type = ERROR_TYPES$DATA,
                                severity = SEVERITY_LEVELS$ERROR
                            )
                            store$set_plot_status(id, "error")

                            direct_table_error_message(paste("Error:", err_msg))
                            NULL
                        }
                    )

                    # Update total rows reactiveVal after data generation attempt
                    n_rows <- if (is.null(fdata)) 0 else nrow(fdata)
                    total_rows_in_data(n_rows) # Update here inside the reactive

                    # Return a list containing data and row count
                    return(list(data = fdata, nrow = n_rows))
                }) # End isolate() for data generation

                return(data_result) # Return result from isolate (the list)
            }), # End reactive expression
            # Cache key arguments for bindCache:
            id,
            current_settings_reactive(),
            current_sim_id_reactive()
        ) # End bindCache

        # --- Table Output: Now depends on full_formatted_data and pagination ---
        output$mainTable <- renderTable(
            {
                # Retrieve the list (potentially cached)
                cached_result <- full_formatted_data()

                # Req required data/state AFTER taking dependencies
                req(!is.null(cached_result), !is.null(cached_result$data), cancelOutput = TRUE) # Stop if data gen failed

                # Extract data and update total rows reactive value *after* cache retrieval
                full_data <- cached_result$data
                total_rows_in_data(cached_result$nrow) # Ensure total_rows is updated even on cache hit

                # Also take dependencies for pagination slicing
                page <- current_page()
                size <- as.numeric(input$page_size %||% 50)

                # Re-req full_data just in case it was NULL inside the list (shouldn't happen with above req)
                req(!is.null(full_data), cancelOutput = TRUE)
                req(input$visualization_state == "visible", cancelOutput = TRUE)
                req(input$display_type == "table", cancelOutput = TRUE)

                # --- Pagination Slicing ---
                # Read the reactiveVal which was just updated
                total_rows <- total_rows_in_data()

                print(paste0("-[ renderTable", id, " ]- Running PAGINATION/SLICING. Page: ", page, ", Size: ", size, ", Total: ", total_rows))

                # Handle invalid page number (reset if needed)
                if (total_rows > 0 && ((page - 1) * size) >= total_rows && page > 1) {
                    print(paste0("-[ renderTable", id, " ]- Page ", page, " invalid. Resetting to page 1."))
                    # Update reactiveVal; this will cause this renderTable to re-run once more
                    current_page(1)
                    # For this run, use page 1 values to avoid error/empty display
                    page <- 1
                }

                start_idx <- max(1, ((page - 1) * size) + 1)
                end_idx <- min(start_idx + size - 1, total_rows)

                if (total_rows == 0 || start_idx > end_idx) {
                    print(paste0("-[ renderTable", id, " ]- No rows to display for this page."))
                    return(NULL) # Return NULL if no rows for current page
                }

                # Slice the data using updated page/size values
                sliced_data <- full_data[start_idx:end_idx, , drop = FALSE]
                print(paste0("-[ renderTable", id, " ]- Displaying rows ", start_idx, "-", end_idx))
                return(sliced_data)
            },
            striped = TRUE,
            hover = TRUE,
            bordered = TRUE
        ) # End renderTable

        # --- Pagination UI Updates ---
        output$page_info <- renderText({
            total <- total_rows_in_data()
            page <- current_page()
            size <- as.numeric(input$page_size %||% 50)

            if (total == 0) {
                return("0-0 of 0")
            }

            start_row <- max(1, ((page - 1) * size) + 1)
            end_row <- min(page * size, total)

            if (end_row < start_row) start_row <- end_row

            sprintf("%d-%d of %d", start_row, end_row, total)
        })

        observe({
            page <- current_page()
            total <- total_rows_in_data()
            size <- as.numeric(input$page_size %||% 50)

            has_prev <- page > 1
            has_next <- (page * size) < total

            updateActionButton(session, "prev_page", disabled = !has_prev)
            updateActionButton(session, "next_page", disabled = !has_next)
        })

        # --- Visibility Observer (Handles Reset Only) ---
        observeEvent(list(input$visualization_state, input$display_type),
            {
                state <- input$visualization_state
                display <- input$display_type
                id_log_prefix <- paste0("-[ TableVisDisp", id, " ]-")
                panel_type <- "table"

                if (!(state == "visible" && display == "table")) {
                    if (!is.null(isolate(direct_table_error_message())) ||
                        isolate(total_rows_in_data() > 0) ||
                        isolate(current_page() != 1) ||
                        isolate(store$get_plot_status(id) == "loading")) {
                        print(paste0(id_log_prefix, " Deactivating. Resetting state..."))
                        isolate({
                            # current_page(1) # Removed to preserve page state on view switch (when hiding)
                            total_rows_in_data(0)
                            validation_boundary$clear()
                            sim_boundary$clear()
                            direct_table_error_message(NULL)
                            store$set_plot_status(id, "ready")
                        })
                    }
                } else {
                    print(paste0(id_log_prefix, " State is active. renderTable will run."))
                    isolate({
                        # current_page(1) # Removed to preserve page state on view switch
                        direct_table_error_message(NULL)
                    })
                }
            },
            ignoreNULL = TRUE,
            ignoreInit = TRUE
        )

        # --- Button Observer (Updates control_manager ONLY) ---
        observeEvent(input$update_visualization, {
            req(input$update_visualization > 0)
            req(input$visualization_state == "visible")
            req(input$display_type == "table")

            print(paste0("-[ TableButton", id, " ]- Clicked."))

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
                print(paste0("-[ TableButton", id, " ]- Updating control_manager ONLY..."))
                str(new_settings)
                control_manager$update_settings(new_settings)
                isolate(current_page(1))
            } else {
                print(paste0("-[ TableButton", id, " ]- Settings validation failed."))
            }
        })

        # --- Pagination Handlers ---
        observeEvent(input$prev_page, {
            req(input$prev_page > 0)
            isolate({
                if (current_page() > 1) {
                    print(paste0("-[ Pagination", id, " ]- Prev clicked."))
                    current_page(current_page() - 1)
                }
            })
        })

        observeEvent(input$next_page, {
            req(input$next_page > 0)
            isolate({
                page <- current_page()
                total <- total_rows_in_data()
                size <- as.numeric(input$page_size %||% 50)

                if ((page * size) < total) {
                    print(paste0("-[ Pagination", id, " ]- Next clicked."))
                    current_page(page + 1)
                }
            })
        })

        observeEvent(input$page_size, {
            print(paste0("-[ Pagination", id, " ]- Size change: ", input$page_size))
            isolate(current_page(1))
        })

        # --- Error handling observers ---
        observe({
            sim_id <- isolate(store$get_current_simulation_id(id))
            sim_state <- if (!is.null(sim_id)) isolate(store$get_simulation(sim_id)) else NULL

            isolate({
                if (!is.null(sim_state) &&
                    sim_state$status == "error" &&
                    !is.null(sim_state$error_message)) {
                    err_msg <- sprintf("Error: %s", as.character(sim_state$error_message))

                    if (is.null(direct_table_error_message()) || direct_table_error_message() != err_msg) {
                        print(paste0("-[ TableSimObserver", id, " ]- Sim error: ", err_msg))

                        sim_boundary$set_error(
                            message = sim_state$error_message,
                            type = ERROR_TYPES$SIMULATION,
                            severity = SEVERITY_LEVELS$ERROR
                        )

                        direct_table_error_message(err_msg)
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

                    if (is.null(direct_table_error_message()) || direct_table_error_message() != err_msg) {
                        print(paste0("-[ TablePersistObserver", id, " ]- Syncing global error: ", err_msg))

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

                        direct_table_error_message(err_msg)
                        store$set_plot_status(id, "error")
                    }
                }
            })
        })

        # --- Debug observer ---
        last_table_error_state <- reactiveVal(list(has_error = FALSE, message = NULL))

        observe({
            error_state <- if (!is.null(sim_boundary)) isolate(sim_boundary$get_state()) else NULL
            error_visible <- !is.null(error_state) && error_state$has_error

            current_direct_error <- direct_table_error_message()
            has_direct_error <- !is.null(current_direct_error) && nzchar(current_direct_error)

            current <- list(
                has_error = error_visible,
                message = if (error_visible) error_state$message else NULL,
                direct_error = has_direct_error
            )

            prev <- last_table_error_state()

            if (!identical(current, prev)) {
                if (error_visible || has_direct_error) {
                    print(sprintf(
                        "[DEBUG_TABLE][%s] Error boundary:%s Direct:%s",
                        id,
                        if (error_visible) "VISIBLE" else "HIDDEN",
                        if (has_direct_error) "VISIBLE" else "HIDDEN"
                    ))
                }

                last_table_error_state(current)
            }
        })

        # --- Download Handler for Table Data ---
        output$downloadTable <- downloadHandler(
            filename = function() {
                # Construct dynamic filename
                sim_id <- current_sim_id_reactive()
                sim_settings_for_file <- store$get_simulation(sim_id)$settings # Get settings used for this sim

                location <- "unknown_location"
                if (!is.null(sim_settings_for_file) && !is.null(sim_settings_for_file$location)) {
                    location <- sim_settings_for_file$location
                }
                location_clean <- gsub("[^A-Za-z0-9_-]", "_", location)

                scenario_name_clean <- ""
                if (id == "prerun" && !is.null(sim_settings_for_file$scenario)) {
                    scenario_val <- sim_settings_for_file$scenario
                    if (!is.null(scenario_val) && nzchar(scenario_val)) {
                        prerun_scenario_options <- NULL
                        if (exists("PRERUN_CONFIG") && !is.null(PRERUN_CONFIG$selectors$scenario$options)) {
                            prerun_scenario_options <- PRERUN_CONFIG$selectors$scenario$options
                        }
                        if (!is.null(prerun_scenario_options) && !is.null(prerun_scenario_options[[scenario_val]]$label)) {
                            scenario_name_clean <- gsub("[^A-Za-z0-9_-]", "_", prerun_scenario_options[[scenario_val]]$label)
                        } else {
                            scenario_name_clean <- gsub("[^A-Za-z0-9_-]", "_", scenario_val)
                        }
                    }
                } else if (id == "custom") {
                    scenario_name_clean <- "CustomSim" # Placeholder for custom scenarios
                }

                current_table_settings <- current_settings_reactive()

                facets_clean <- "NoFacets"
                if (!is.null(current_table_settings$facet.by) && length(current_table_settings$facet.by) > 0) {
                    facets_clean <- paste(sapply(current_table_settings$facet.by, function(f) gsub("[^A-Za-z0-9_-]", "_", f)), collapse = "-")
                }

                summary_type_clean <- "NoSummary"
                if (!is.null(current_table_settings$summary.type) && nzchar(current_table_settings$summary.type)) {
                    summary_type_clean <- gsub("[^A-Za-z0-9_-]", "_", current_table_settings$summary.type)
                }

                timestamp <- format(Sys.time(), "%H%M%S")

                filename_parts <- c(
                    "jheem_table",
                    id,
                    location_clean
                )
                if (nzchar(scenario_name_clean)) {
                    filename_parts <- c(filename_parts, scenario_name_clean)
                }
                filename_parts <- c(
                    filename_parts,
                    facets_clean,
                    summary_type_clean,
                    Sys.Date(),
                    timestamp
                )

                filename_final <- paste(filename_parts, collapse = "_")
                filename_final <- paste0(filename_final, ".csv")

                filename_final
            },
            content = function(file) {
                # Access the full data from the reactive expression
                data_to_download <- full_formatted_data()$data

                if (!is.null(data_to_download) && nrow(data_to_download) > 0) {
                    tryCatch(
                        {
                            write.csv(data_to_download, file, row.names = FALSE, na = "")
                        },
                        error = function(e) {
                            showNotification(paste("Error downloading table data:", e$message), type = "error")
                            # Create an empty file to prevent Shiny error if write fails
                            file.create(file)
                        }
                    )
                } else {
                    showNotification("No table data available to download.", type = "warning")
                    # Create an empty file to prevent Shiny error
                    file.create(file)
                }
            }
        )
    }) # END moduleServer
}
