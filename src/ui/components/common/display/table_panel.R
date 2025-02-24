# src/ui/components/common/display/table_panel.R

#' Create the table panel UI component
#' @param id Panel identifier
#' @return Shiny UI element containing the table panel
create_table_panel <- function(id) {
  ns <- NS(id)

  tags$div(
    class = "main-panel main-panel-table",
    conditionalPanel(
      condition = sprintf(
        "input['%s'] === 'visible' && input['%s'] === 'table'",
        ns("visualization_state"),
        ns("display_type")
      ),
      tags$div(
        class = "panel-container",
        tags$div(
          class = "panel-content",
          # Table content
          tableOutput(ns("mainTable")),
          # Pagination controls
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
                tags$span(
                  class = "page-info",
                  textOutput(ns("page_info"), inline = TRUE)
                ),
                actionButton(ns("next_page"), "Next", class = "btn-pagination")
              )
            )
          ),
          # Loading indicator
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
      class = "plot-error error",
      textOutput(ns("error_message"))
    )
  )
}

#' Table panel server logic
#' @param id Panel identifier
#' @param data Reactive source for table data
#' @param settings Reactive source for display settings
#' @return None
table_panel_server <- function(id, settings) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    store <- get_store()

    # Get config once at initialization
    config <- get_component_config("controls")

    # Create state managers
    vis_manager <- create_visualization_manager(session, id, ns("visualization"))
    control_manager <- create_control_manager(session, id, ns("controls"), settings)

    # Create validation boundary
    validation_boundary <- create_validation_boundary(
      session,
      output,
      id,
      "validation",
      state_manager = vis_manager
    )

    # Add pagination state
    current_page <- reactiveVal(1)
    has_more_data <- reactiveVal(FALSE)

    # Table output with pagination
    output$mainTable <- renderTable({
      req(input$visualization_state == "visible")
      req(input$display_type == "table")

      vis_manager$set_plot_status("loading")
      current_settings <- control_manager$get_settings()

      tryCatch({
        # Get transformed data - this will retransform if settings changed
        transformed_data <- store$get_current_transformed_data(id, current_settings)
        
        # Format and paginate
        formatted <- format_table_data(transformed_data, get_component_config("controls"))
        
        # Apply pagination
        total_rows <- nrow(formatted)
        start_idx <- ((current_page() - 1) * as.numeric(input$page_size %||% 50)) + 1
        end_idx <- min(start_idx + as.numeric(input$page_size %||% 50) - 1, total_rows)
        
        # Create result structure
        result <- list(
            data = formatted[start_idx:end_idx, , drop = FALSE],
            metadata = list(
                total_rows = total_rows,
                current_page = current_page(),
                has_more = end_idx < total_rows
            )
        )

        # Update pagination state
        has_more_data(result$metadata$has_more)

        # Update pagination info if available
        if (!is.null(result$metadata)) {
            output$page_info <- renderText({
                total <- result$metadata$total_rows
                page <- result$metadata$current_page
                size <- as.numeric(input$page_size %||% 50)
                start_row <- ((page - 1) * size) + 1
                end_row <- min(page * size, total)
                sprintf("%d-%d of %d", start_row, end_row, total)
            })
        }

        output$error_message <- renderText({ NULL })
        vis_manager$set_plot_status("ready")

        result$data
      }, error = function(e) {
        print(paste("Error in table creation:", conditionMessage(e)))
        output$error_message <- renderText({
          sprintf("Error: %s", conditionMessage(e))
        })
        NULL
      })
    })

    # Combined observer for all control changes
    observe({
      print("=== Table Panel Control Update ===")

      # Get all current control values
      outcomes <- input[[paste0("outcomes_", id)]]
      facet_by <- input[[paste0("facet_by_", id)]]
      summary_type <- input[[paste0("summary_type_", id)]]

      print("Current control values:")
      print(paste("- outcomes:", paste(outcomes, collapse = ", ")))
      print(paste("- facet_by:", paste(facet_by, collapse = ", ")))
      print(paste("- summary_type:", summary_type))

      # Only proceed if we have a visible table and any controls are set
      if (!is.null(input$visualization_state) &&
        input$visualization_state == "visible" &&
        input$display_type == "table" &&
        (!is.null(outcomes) || !is.null(facet_by) || !is.null(summary_type))) {
        # Get current settings with isolate
        current_settings <- isolate(control_manager$get_settings())

        # Create settings update
        new_settings <- list(
          outcomes = if (!is.null(outcomes)) as.character(outcomes) else current_settings$outcomes,
          facet.by = if (!is.null(facet_by)) as.character(facet_by) else current_settings$facet.by,
          summary.type = if (!is.null(summary_type)) summary_type else current_settings$summary.type
        )

        print("Settings for table:")
        str(new_settings)

        # Update state and table together
        isolate({
          # Update control state
          control_manager$update_settings(new_settings)
          current_page(1) # Reset to first page on control changes

          # Update table display
          vis_manager$set_plot_status("loading")
          output$mainTable <- renderTable({
            tryCatch({
              # Get transformed data - this will retransform if settings changed
              transformed_data <- store$get_current_transformed_data(id, new_settings)
              
              # Format and paginate
              formatted <- format_table_data(transformed_data, get_component_config("controls"))
              
              # Apply pagination
              total_rows <- nrow(formatted)
              start_idx <- ((current_page() - 1) * as.numeric(input$page_size %||% 50)) + 1
              end_idx <- min(start_idx + as.numeric(input$page_size %||% 50) - 1, total_rows)
              
              # Create result structure
              result <- list(
                  data = formatted[start_idx:end_idx, , drop = FALSE],
                  metadata = list(
                      total_rows = total_rows,
                      current_page = current_page(),
                      has_more = end_idx < total_rows
                  )
              )

              # Update pagination state
              has_more_data(result$metadata$has_more)

              output$error_message <- renderText({ NULL })
              vis_manager$set_plot_status("ready")

              result$data
              },
              error = function(e) {
                print(paste("Error in table update:", conditionMessage(e)))
                output$error_message <- renderText({
                  sprintf("Error: %s", conditionMessage(e))
                })
                NULL
              }
            )
          })
        })
      }
    })

    # Pagination handlers
    observeEvent(input$prev_page, {
      if (current_page() > 1) {
        current_page(current_page() - 1)
      }
    })

    observeEvent(input$next_page, {
      if (has_more_data()) {
        current_page(current_page() + 1)
      }
    })

    observeEvent(input$page_size, {
      current_page(1) # Reset to first page when changing page size
    })

    # Reset states when visibility changes
    observeEvent(input$visualization_state, {
      if (input$visualization_state == "hidden") {
        vis_manager$reset()
        control_manager$reset()
        validation_boundary$clear()
        current_page(1) # Reset pagination
        has_more_data(FALSE) # Reset has_more_data
        output$error_message <- renderText({
          NULL
        })
      }
    })

    # Update button states
    observe({
      if (current_page() <= 1) {
        updateActionButton(session, "prev_page", label = "Previous", disabled = TRUE)
      } else {
        updateActionButton(session, "prev_page", label = "Previous", disabled = FALSE)
      }

      if (!has_more_data()) {
        updateActionButton(session, "next_page", label = "Next", disabled = TRUE)
      } else {
        updateActionButton(session, "next_page", label = "Next", disabled = FALSE)
      }
    })
  })
}
