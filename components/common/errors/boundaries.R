# components/common/errors/boundaries.R

#' Create an error boundary component
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @return List of error handling functions
create_error_boundary <- function(session, output, page_id, id) {
    ns <- session$ns
    print("Creating error boundary")
    print(paste("page_id:", page_id))
    print(paste("id:", id))
    
    # Initialize error state
    error_state <- reactiveVal(list(
        has_error = FALSE,
        message = "",
        type = "",        
        details = NULL,   
        timestamp = NULL  
    ))
    
    # Define error management functions
    local({
        print("Defining error management functions")
        
        set_error <- function(message, type = "general", details = NULL) {
            print(sprintf("Setting error: %s (%s)", message, type))
            isolate({
                error_state(list(
                    has_error = TRUE,
                    message = message,
                    type = type,
                    details = details,
                    timestamp = Sys.time()
                ))
                
                if (type == "validation") {
                    output[[ns("validation_error")]] <- renderUI({
                        tags$div(
                            class = "validation-error",
                            tags$span(class = "error-icon", "⚠"),
                            tags$span(message)
                        )
                    })
                } else if (type == "plot") {
                    output[[ns("plot_error")]] <- renderUI({
                        tags$div(
                            class = "plot-error",
                            tags$span(class = "error-icon", "⚠"),
                            tags$span(message),
                            if (!is.null(details)) {
                                tags$pre(class = "error-details", details)
                            }
                        )
                    })
                }
            })
        }
        
        clear_error <- function() {
            print("Clearing error state")
            isolate({
                error_state(list(
                    has_error = FALSE,
                    message = "",
                    type = "",
                    details = NULL,
                    timestamp = NULL
                ))
                
                output[[ns("validation_error")]] <- renderUI({ NULL })
                output[[ns("plot_error")]] <- renderUI({ NULL })
            })
        }
        
        handle <- function(expr, type = "general", message = NULL) {
            print(sprintf("Handling expression with type: %s", type))
            tryCatch({
                if (error_state()$type == type) {
                    clear_error()
                }
                expr
            }, error = function(e) {
                set_error(
                    message = message %||% conditionMessage(e),
                    type = type,
                    details = conditionMessage(e)
                )
                NULL
            }, warning = function(w) {
                print(sprintf("Warning in %s: %s", type, conditionMessage(w)))
                expr
            })
        }
        
        # Return functions in environment
        environment()
    }) -> error_fns
    
    error_interface <- list(
        set_error = error_fns$set_error,
        clear_error = error_fns$clear_error,
        get_error = reactive({ error_state() }),
        has_error = reactive({ error_state()$has_error }),
        ui = function() {
            tags$div(
                class = "error-boundary",
                uiOutput(ns("validation_error")),
                uiOutput(ns("plot_error"))
            )
        },
        handle = error_fns$handle
    )
    
    print("Created error interface:")
    str(error_interface)
    error_interface
}

#' Create validation error boundary
#' Specialized error boundary for validation errors
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @return Validation error handler
create_validation_boundary <- function(session, output, page_id, id) {
    error_boundary <- create_error_boundary(session, output, page_id, id)
    
    list(
        # Validate with custom rules
        validate = function(value, rules) {
            for (rule in rules) {
                if (!rule$test(value)) {
                    error_boundary$set_error(rule$message, "validation")
                    return(FALSE)
                }
            }
            error_boundary$clear_error()
            TRUE
        },
        
        # Common validation rules
        rules = list(
            required = function(message = "This field is required") {
                list(
                    test = function(value) !is.null(value) && length(value) > 0,
                    message = message
                )
            },
            type = function(type, message = sprintf("Must be of type %s", type)) {
                list(
                    test = function(value) inherits(value, type),
                    message = message
                )
            },
            custom = function(test_fn, message) {
                list(
                    test = test_fn,
                    message = message
                )
            }
        ),
        
        # Access to base error boundary functions
        ui = error_boundary$ui,
        clear = error_boundary$clear_error,  # Add this
        get_state = error_boundary$get_error,
        set_error = error_boundary$set_error  # Add this
    )
}

#' Create plot error boundary
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @return Plot error handler
create_plot_boundary <- function(session, output, page_id, id) {
    print("Creating plot boundary")
    error_boundary <- create_error_boundary(session, output, page_id, id)
    print("Plot boundary error functions:")
    str(error_boundary)
    
    interface <- list(
        handle_plot = function(plot_expr) {
            error_boundary$handle(plot_expr, type = "plot", message = "Error generating plot")
        },
        handle_data = function(data_expr) {
            error_boundary$handle(data_expr, type = "plot", message = "Error processing plot data")
        },
        handle_settings = function(settings_expr) {
            error_boundary$handle(settings_expr, type = "plot", message = "Error processing plot settings")
        },
        clear = error_boundary$clear_error,
        set_error = error_boundary$set_error,
        ui = error_boundary$ui,
        get_state = error_boundary$get_error
    )
    
    print("Created plot boundary interface:")
    str(interface)
    interface
}