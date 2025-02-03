# src/ui/components/common/errors/boundaries.R

#' Error type definitions
#' @return List of error type constants
ERROR_TYPES <- list(
    VALIDATION = "validation",
    PLOT = "plot",
    DATA = "data",
    SYSTEM = "system",
    STATE = "state"
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
    print(sprintf("Creating error boundary for %s on page %s", id, page_id))

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
            print("=== Rendering Error Display ===")
            current_error <- error_state()
            print("Current error state:")
            str(current_error)

            if (!current_error$has_error) {
                print("No error to display")
                return(NULL)
            }

            print(sprintf("Rendering error UI for type: %s", current_error$type))

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
            print("Error UI generated")
            result
        })
    })

    # Define error management functions
    local({
        print("Defining error management functions")

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
                    state_manager$set_plot_status("error")
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
                    state_manager$set_plot_status("ready")
                }
            })
        }

        # Other functions same as before...
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
            print("Validating value:") # Debug
            print(value)
            print("With rules:")
            str(rules)

            for (rule in rules) {
                print("Testing rule:") # Debug
                str(rule)

                if (!rule$test(value)) {
                    print(sprintf("Validation failed with message: %s", rule$message)) # Debug
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
            print("All validations passed") # Debug
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
                print(sprintf("Creating required rule with message: %s", message))

                list(
                    test = function(value) {
                        result <- !is.null(value) &&
                            length(value) > 0 &&
                            !is.na(value) &&
                            (!is.character(value) || nchar(trimws(value)) > 0)
                        print(sprintf("Required test result: %s", result))
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
                print(sprintf("Creating range rule with message: %s", message))

                list(
                    test = function(value) {
                        if (is.null(value) || is.na(value) || !is.numeric(value)) {
                            print("Range test failed: invalid value type")
                            return(FALSE)
                        }
                        min_ok <- is.null(min) || value >= min
                        max_ok <- is.null(max) || value <= max
                        result <- min_ok && max_ok
                        print(sprintf("Range test result: %s", result))
                        result
                    },
                    message = message,
                    severity = severity
                )
            },
            custom = function(test_fn,
                              message,
                              severity = SEVERITY_LEVELS$ERROR) {
                print("Creating custom rule with message:") # Debug
                print(message)
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

#' Create plot error boundary
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param state_manager Optional visualization manager for integration
#' @return Plot error handler
create_plot_boundary <- function(session, output, page_id, id, state_manager = NULL) {
    print("Creating plot boundary")
    error_boundary <- create_error_boundary(session, output, page_id, id, state_manager)
    print("Plot boundary error functions:")
    str(error_boundary)

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
