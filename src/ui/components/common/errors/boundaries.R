# src/ui/components/common/errors/boundaries.R

#' Error type definitions
#' @return List of error type constants
ERROR_TYPES <- list(
    VALIDATION = "validation",
    PLOT = "plot",
    DATA = "data",
    SYSTEM = "system",
    STATE = "state",
    SIMULATION = "simulation", # Simulation errors
    SIMULATION_CACHE = "sim_cache", # Simulation cache errors
    DOWNLOAD = "download" # Download errors
)

#' Error severity levels
#' @return List of severity level constants
SEVERITY_LEVELS <- list(
    WARNING = "warning",
    ERROR = "error",
    FATAL = "fatal"
)

#' Global error registry for cross-component communication
error_registry <- new.env()

#' Create an error state
#' @param message Error message
#' @param type Error type from ERROR_TYPES
#' @param severity Error severity from SEVERITY_LEVELS
#' @param details Optional details about the error
#' @param source Optional source component ID
#' @return List representing error state
create_error_state <- function(message,
                               type = ERROR_TYPES$SYSTEM,
                               severity = SEVERITY_LEVELS$ERROR,
                               details = NULL,
                               source = NULL) {
    list(
        has_error = TRUE,
        message = message,
        type = type,
        severity = severity,
        details = details,
        source = source,
        timestamp = Sys.time()
    )
}

#' Create an error boundary component
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param state_manager Optional visualization manager for integration
#' @return List of error handling functions
create_error_boundary <- function(session, output, page_id, id, state_manager = NULL) {
    ns <- session$ns
    # print(sprintf("Creating error boundary for %s on page %s", id, page_id)) # Commented out

    # Initialize error state
    error_state <- reactiveVal(list(
        has_error = FALSE,
        message = "",
        type = "",
        severity = "",
        details = NULL,
        source = NULL,
        timestamp = NULL
    ))

    # Register this boundary in the global registry
    error_registry[[id]] <- NULL

    # Create reactive error display
    local({
        output[[ns("error_display")]] <- renderUI({
            # print("=== Rendering Error Display ===") # Commented out
            current_error <- error_state()
            # print("Current error state:") # Commented out
            # str(current_error) # Commented out

            if (!current_error$has_error) {
                # print("No error to display") # Commented out
                return(NULL)
            }

            # print(sprintf("Rendering error UI for type: %s", current_error$type)) # Commented out

            # Create error display based on type
            result <- if (current_error$type == ERROR_TYPES$VALIDATION) {
                tags$div(
                    class = paste("validation-error", current_error$severity),
                    tags$span(class = "error-icon", "⚠"),
                    tags$span(class = "error-message", current_error$message),
                    if (!is.null(current_error$details)) {
                        tags$div(class = "error-details", current_error$details)
                    }
                )
            } else {
                tags$div(
                    class = paste("component-error", current_error$severity),
                    tags$span(class = "error-icon", "⚠"),
                    tags$span(class = "error-message", current_error$message),
                    if (!is.null(current_error$details)) {
                        tags$pre(class = "error-details", current_error$details)
                    }
                )
            }
            # print("Error UI generated") # Commented out
            result
        })
    })

    # Define error management functions
    local({
        # print("Defining error management functions") # Commented out

        set_error <- function(message, type = ERROR_TYPES$SYSTEM,
                              severity = SEVERITY_LEVELS$ERROR,
                              details = NULL,
                              source = NULL) {
            print(sprintf("Setting %s error: %s", type, message))
            isolate({
                new_state <- create_error_state(
                    message = message,
                    type = type,
                    severity = severity,
                    details = details,
                    source = source %||% id
                )
                error_state(new_state)

                # Update visualization status if manager provided
                if (!is.null(state_manager) && !is.null(state_manager$set_plot_status)) {
                    # Don't pass page_id - visualization manager already has it in closure
                    print(sprintf(
                        "[ERROR_BOUNDARY] Setting plot status to 'error' using %s",
                        if ("update_visualization_state" %in% names(state_manager)) "store" else "visualization manager"
                    ))
                    state_manager$set_plot_status("error")
                } else {
                    print("[ERROR_BOUNDARY] No state_manager with set_plot_status available")
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
                    severity = "",
                    details = NULL,
                    source = NULL,
                    timestamp = NULL
                ))

                # Update visualization status if manager provided
                if (!is.null(state_manager) && !is.null(state_manager$set_plot_status)) {
                    # Don't pass page_id - visualization manager already has it in closure
                    print(sprintf(
                        "[ERROR_BOUNDARY] Clearing error and setting plot status to 'ready' using %s",
                        if ("update_visualization_state" %in% names(state_manager)) "store" else "visualization manager"
                    ))
                    state_manager$set_plot_status("ready")
                } else {
                    print("[ERROR_BOUNDARY] No state_manager with set_plot_status available for clearing error")
                }
            })
        }

        # Handle expressions with error handling
        handle <- function(expr, type = ERROR_TYPES$SYSTEM, message = NULL, severity = SEVERITY_LEVELS$ERROR, propagate = FALSE) {
            print("Handling expression with error boundary")
            tryCatch(
                {
                    result <- expr
                    # Clear any existing error
                    clear_error()
                    return(result)
                },
                error = function(e) {
                    # Get error message
                    error_msg <- if (is.null(message)) {
                        as.character(e$message)
                    } else {
                        paste0(message, ": ", as.character(e$message))
                    }

                    print(sprintf("Expression error caught: %s", error_msg))

                    # Set error in this boundary
                    set_error(
                        message = error_msg,
                        type = type,
                        severity = severity,
                        details = as.character(e)
                    )

                    # Propagate to parent if requested
                    if (propagate && !is.null(error_registry[[id]])) {
                        error_registry[[id]]$propagate_error(error_msg, type, severity)
                    }

                    # Return NULL to indicate failure
                    NULL
                }
            )
        }

        # Propagate errors to parent components
        propagate_error <- function(message, type = ERROR_TYPES$SYSTEM, severity = SEVERITY_LEVELS$ERROR) {
            # Implementation would depend on the registry structure
            print("Error propagation not yet implemented")
        }

        environment()
    }) -> error_fns

    # Create error interface
    error_interface <- list(
        set_error = error_fns$set_error,
        clear_error = error_fns$clear_error,
        get_error = reactive({
            error_state()
        }),
        has_error = reactive({
            error_state()$has_error
        }),
        propagate_error = error_fns$propagate_error,
        ui = function() {
            current_error <- error_state()

            if (!current_error$has_error) {
                return(NULL)
            }

            if (current_error$type == ERROR_TYPES$VALIDATION) {
                tags$div(
                    class = paste("validation-error", current_error$severity),
                    tags$span(class = "error-icon", "⚠"),
                    tags$span(class = "error-message", current_error$message),
                    if (!is.null(current_error$details)) {
                        tags$div(class = "error-details", current_error$details)
                    }
                )
            } else {
                tags$div(
                    class = paste("plot-error", current_error$severity),
                    tags$span(class = "error-icon", "⚠"),
                    tags$span(class = "error-message", current_error$message),
                    if (!is.null(current_error$details)) {
                        tags$pre(class = "error-details", current_error$details)
                    }
                )
            }
        },
        handle = error_fns$handle
    )

    # Register interface in global registry
    error_registry[[id]] <- error_interface

    # print("Created error interface:") # Commented out
    # str(error_interface) # Commented out
    error_interface
}

#' Create validation error boundary
#' Specialized error boundary for validation errors
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param state_manager Optional visualization manager for integration
#' @param validation_manager Optional validation manager for state tracking
#' @return Validation error handler
create_validation_boundary <- function(session, output, page_id, id,
                                       state_manager = NULL,
                                       validation_manager = NULL) {
    error_boundary <- create_error_boundary(session, output, page_id, id, state_manager)

    list(
        # Validate with custom rules
        validate = function(value, rules, field_id = id, severity = SEVERITY_LEVELS$ERROR) {
            # print("Validating value:") # Debug - Commented out
            # print(value) # Debug - Commented out
            # print("With rules:") # Debug - Commented out
            # str(rules) # Debug - Commented out

            for (rule in rules) {
                # print("Testing rule:") # Debug - Commented out
                # str(rule) # Debug - Commented out

                if (!rule$test(value)) {
                    # print(sprintf("Validation failed with message: %s", rule$message)) # Keep print for actual validation failure
                    error_boundary$set_error(
                        message = rule$message,
                        type = ERROR_TYPES$VALIDATION,
                        severity = severity
                    )
                    # Update validation state if manager provided
                    if (!is.null(validation_manager)) {
                        validation_manager$update_field(field_id, FALSE, rule$message)
                    }
                    return(FALSE)
                }
            }
            # print("All validations passed") # Debug - Commented out
            error_boundary$clear_error()
            # Update validation state if manager provided
            if (!is.null(validation_manager)) {
                validation_manager$update_field(field_id, TRUE)
            }
            TRUE
        },

        # Common validation rules
        rules = list(
            required = function(message,
                                severity = SEVERITY_LEVELS$ERROR) {
                if (is.null(message) || length(message) == 0) {
                    message <- "This field is required"
                }
                # print(sprintf("Creating required rule with message: %s", message)) # Commented out

                list(
                    test = function(value) {
                        result <- !is.null(value) &&
                            length(value) > 0 &&
                            !is.na(value) &&
                            (!is.character(value) || nchar(trimws(value)) > 0)
                        # print(sprintf("Required test result: %s", result)) # Commented out
                        result
                    },
                    message = message,
                    severity = severity
                )
            },
            type = function(type,
                            message = sprintf("Must be of type %s", type),
                            severity = SEVERITY_LEVELS$ERROR) {
                list(
                    test = function(value) inherits(value, type),
                    message = message,
                    severity = severity
                )
            },
            range = function(min = NULL,
                             max = NULL,
                             message = NULL,
                             severity = SEVERITY_LEVELS$ERROR) {
                if (is.null(message) || length(message) == 0) {
                    message <- sprintf(
                        "Value must be between %s and %s",
                        if (is.null(min)) "-∞" else min,
                        if (is.null(max)) "∞" else max
                    )
                }
                # print(sprintf("Creating range rule with message: %s", message)) # Commented out

                list(
                    test = function(value) {
                        if (is.null(value) || is.na(value) || !is.numeric(value)) {
                            print("Range test failed: invalid value type")
                            return(FALSE)
                        }
                        min_ok <- is.null(min) || value >= min
                        max_ok <- is.null(max) || value <= max
                        result <- min_ok && max_ok
                        # print(sprintf("Range test result: %s", result)) # Commented out
                        result
                    },
                    message = message,
                    severity = severity
                )
            },
            custom = function(test_fn,
                              message,
                              severity = SEVERITY_LEVELS$ERROR) {
                # print("Creating custom rule with message:") # Debug - Commented out
                # print(message) # Debug - Commented out
                list(
                    test = test_fn,
                    message = message,
                    severity = severity
                )
            }
        ),

        # Access to base error boundary functions
        ui = error_boundary$ui,
        clear = error_boundary$clear_error,
        get_state = error_boundary$get_error,
        set_error = error_boundary$set_error,
        propagate_error = error_boundary$propagate_error
    )
}

#' Create simulation error boundary
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param state_manager Optional visualization manager for integration
#' @return Simulation error handler
create_simulation_boundary <- function(session, output, page_id, id, state_manager = NULL) {
    # print(sprintf("Creating simulation boundary for %s on page %s", id, page_id)) # Commented out
    error_boundary <- create_error_boundary(session, output, page_id, id, state_manager) # Inner creation print already commented

    list(
        # Handle simulation errors
        handle_simulation = function(expr, severity = SEVERITY_LEVELS$ERROR) {
            error_boundary$handle(
                expr,
                type = ERROR_TYPES$SIMULATION,
                message = "Error in simulation",
                severity = severity
            )
        },

        # Handle cache errors
        handle_cache = function(expr, severity = SEVERITY_LEVELS$WARNING) {
            error_boundary$handle(
                expr,
                type = ERROR_TYPES$SIMULATION_CACHE,
                message = "Error with simulation cache",
                severity = severity
            )
        },

        # Inherit base error boundary methods
        clear = error_boundary$clear_error,
        set_error = error_boundary$set_error,
        ui = error_boundary$ui,
        get_state = error_boundary$get_error,
        propagate_error = error_boundary$propagate_error
    )
}

#' Create simulation cache error boundary
#' Specialized for cache operations
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param state_manager Optional visualization manager for integration
#' @return Cache error handler
create_simulation_cache_boundary <- function(session, output, page_id, id, state_manager = NULL) {
    # print(sprintf("Creating simulation cache boundary for %s on page %s", id, page_id)) # Commented out
    error_boundary <- create_error_boundary(session, output, page_id, id, state_manager) # Inner creation print already commented

    list(
        # Cache-specific handlers
        handle_cache_read = function(expr, severity = SEVERITY_LEVELS$WARNING) {
            error_boundary$handle(
                expr,
                type = ERROR_TYPES$SIMULATION_CACHE,
                message = "Error reading from simulation cache",
                severity = severity
            )
        },
        handle_cache_write = function(expr, severity = SEVERITY_LEVELS$WARNING) {
            error_boundary$handle(
                expr,
                type = ERROR_TYPES$SIMULATION_CACHE,
                message = "Error writing to simulation cache",
                severity = severity
            )
        },

        # Include base error boundary methods
        clear = error_boundary$clear_error,
        set_error = error_boundary$set_error,
        ui = error_boundary$ui,
        get_state = error_boundary$get_error,
        propagate_error = error_boundary$propagate_error
    )
}

#' Create plot error boundary
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param state_manager Optional visualization manager for integration
#' @return Plot error handler
create_plot_boundary <- function(session, output, page_id, id, state_manager = NULL) {
    # print("Creating plot boundary") # Commented out
    error_boundary <- create_error_boundary(session, output, page_id, id, state_manager) # Inner creation print already commented
    # print("Plot boundary error functions:") # Commented out
    # str(error_boundary) # Commented out

    list(
        handle_plot = function(plot_expr, severity = SEVERITY_LEVELS$ERROR) {
            error_boundary$handle(
                plot_expr,
                type = ERROR_TYPES$PLOT,
                message = "Error generating plot",
                severity = severity
            )
        },
        handle_data = function(data_expr, severity = SEVERITY_LEVELS$ERROR) {
            error_boundary$handle(
                data_expr,
                type = ERROR_TYPES$DATA,
                message = "Error processing plot data",
                severity = severity
            )
        },
        handle_settings = function(settings_expr, severity = SEVERITY_LEVELS$ERROR) {
            error_boundary$handle(
                settings_expr,
                type = ERROR_TYPES$STATE,
                message = "Error processing plot settings",
                severity = severity
            )
        },

        # Handle warnings as non-fatal errors
        handle_warning = function(expr, message) {
            error_boundary$handle(
                expr,
                type = ERROR_TYPES$PLOT,
                message = message,
                severity = SEVERITY_LEVELS$WARNING
            )
        },
        clear = error_boundary$clear_error,
        set_error = error_boundary$set_error,
        ui = error_boundary$ui,
        get_state = error_boundary$get_error,
        propagate_error = error_boundary$propagate_error
    )
}
