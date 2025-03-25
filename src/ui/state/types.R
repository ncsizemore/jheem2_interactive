# src/ui/state/types.R

#' Create a visualization state object
#' @param visibility Character: "visible", "hidden", or "loading"
#' @param plot_status Character: "ready", "loading", or "error"
#' @param display_type Character: "plot" or "table"
#' @param error_message Character: Error message if any
#' @return List with visualization state properties
create_visualization_state <- function(
    visibility = "hidden",
    plot_status = "ready",
    display_type = "plot", # Default to plot view
    error_message = "") {
    validate_visualization_state(list(
        visibility = visibility,
        plot_status = plot_status,
        display_type = display_type,
        error_message = error_message
    ))
}

#' Create a simulation state object
#' @param id Character: unique simulation identifier
#' @param mode Character: "prerun" or "custom"
#' @param settings List: complete simulation settings
#' @param results List: simulation results including transformed data
#' @param timestamp POSIXct: when simulation was created/updated
#' @param status Character: simulation status
#' @return List with simulation state properties
create_simulation_state <- function(
    id,
    mode,
    settings = list(),
    results = list(simset = NULL, transformed = NULL),
    timestamp = Sys.time(),
    status = "ready",
    progress = NULL) {
    validate_simulation_state(list(
        id = id,
        mode = mode,
        settings = settings,
        results = results,
        timestamp = timestamp,
        status = status,
        progress = progress
    ))
}

#' Validate simulation state object
#' @param state List containing simulation state properties
#' @return The state object if valid, otherwise throws error
validate_simulation_state <- function(state) {
    if (!is.list(state)) stop("Simulation state must be a list")

    # Required fields
    required <- c("id", "mode", "settings", "results", "timestamp", "status")
    missing <- setdiff(required, names(state))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required simulation state fields: %s",
            paste(missing, collapse = ", ")
        ))
    }
    
    # Add progress field if missing
    if (!"progress" %in% names(state)) {
        state$progress <- NULL
    }
    
    # Preserve original_base_simset field if it exists
    # This ensures it's not removed during validation

    # Validate id
    if (!is.character(state$id) || length(state$id) != 1) {
        stop("id must be a single character string")
    }

    # Validate mode
    if (!state$mode %in% c("prerun", "custom")) {
        stop("mode must be either 'prerun' or 'custom'")
    }

    # Validate settings
    if (!is.list(state$settings)) {
        stop("settings must be a list")
    }

    # Validate results structure
    if (!is.list(state$results)) {
        stop("results must be a list")
    }
    if (!all(c("simset", "transformed") %in% names(state$results))) {
        stop("results must contain 'simset' and 'transformed' elements")
    }

    # Validate timestamp
    if (!inherits(state$timestamp, "POSIXct")) {
        stop("timestamp must be a POSIXct object")
    }

    # Validate status
    valid_statuses <- c("ready", "running", "complete", "error")
    if (!state$status %in% valid_statuses) {
        stop(sprintf(
            "Invalid status. Must be one of: %s",
            paste(valid_statuses, collapse = ", ")
        ))
    }
    
    # Validate progress field if present
    if (!is.null(state$progress)) {
        if (!is.list(state$progress)) {
            stop("progress must be a list or NULL")
        }
        
        # Required fields for progress
        progress_fields <- c("percentage", "current", "total")
        missing_progress <- setdiff(progress_fields, names(state$progress))
        if (length(missing_progress) > 0) {
            # Create default values for missing fields
            for (field in missing_progress) {
                state$progress[[field]] <- switch(field,
                    percentage = 0,
                    current = 0,
                    total = 0
                )
            }
        }
        
        # Ensure percentage is within bounds
        state$progress$percentage <- min(100, max(0, state$progress$percentage))
    }

    state
}

#' Create download progress state structure
#' @return List with default download progress state
create_download_progress_state <- function() {
  list(
    active_downloads = list(),  # Currently downloading files
    completed_downloads = list(), # Successfully completed downloads
    failed_downloads = list(), # Failed downloads with error messages
    last_updated = Sys.time()
  )
}

#' Validate download progress state
#' @param state Download progress state to validate
#' @return Validated state with default values for missing fields
validate_download_progress_state <- function(state) {
  if (is.null(state)) {
    return(create_download_progress_state())
  }
  
  # Ensure all required fields exist
  if (is.null(state$active_downloads)) {
    state$active_downloads <- list()
  }
  if (is.null(state$completed_downloads)) {
    state$completed_downloads <- list()
  }
  if (is.null(state$failed_downloads)) {
    state$failed_downloads <- list()
  }
  if (is.null(state$last_updated)) {
    state$last_updated <- Sys.time()
  }
  
  state
}

#' Create download entry structure
#' @param id Unique identifier for the download
#' @param filename Name of the file being downloaded
#' @param total_size Total size of the file in bytes (if known)
#' @return List representing a download entry
create_download_entry <- function(id, filename, total_size = NULL) {
  list(
    id = id,
    filename = filename,
    start_time = Sys.time(),
    percent = 0,
    total_size = total_size,
    last_updated = Sys.time()
  )
}

#' Create a simulation progress state structure
#' @param current Current index of the simulation
#' @param total Total number of simulations to run
#' @param percentage Optional direct percentage value (0-100)
#' @param done Whether the current simulation is complete
#' @return List with progress state information
create_simulation_progress <- function(current = 0, total = 0, percentage = NULL, done = FALSE) {
  # Calculate percentage if not directly provided
  if (is.null(percentage)) {
    if (total > 0) {
      percentage <- min(100, round((current / total) * 100))
    } else {
      percentage <- 0
    }
  }
  
  # Clamp percentage to valid range
  percentage <- min(100, max(0, percentage))
  
  list(
    current = current,
    total = total,
    percentage = percentage,
    done = done,
    last_updated = Sys.time()
  )
}

#' Create a new control state object
#' @param outcomes Character vector of selected outcomes
#' @param facet_by Character vector of faceting dimensions
#' @param summary_type Character: type of summary to display
#' @return List with control state properties
create_control_state <- function(outcomes = NULL,
                                 facet_by = NULL,
                                 summary_type = "mean.and.interval") {
    # Get defaults from config if not provided
    config <- get_component_config("controls")
    if (is.null(outcomes)) {
        outcomes <- config$plot_controls$outcomes$defaults
    }
    if (is.null(facet_by)) {
        facet_by <- config$plot_controls$stratification$defaults
    }

    validate_control_state(list(
        outcomes = outcomes,
        facet.by = facet_by,
        summary.type = summary_type
    ))
}

#' Create a new panel state object
#' @param page_id Character: page identifier
#' @param visualization Visualization state object
#' @param controls Control state object
#' @param validation Validation state object
#' @return List with panel state properties
create_panel_state <- function(page_id,
                               visualization = create_visualization_state(),
                               controls = create_control_state(),
                               validation = create_validation_state(),
                               current_simulation_id = NULL) {
    validate_panel_state(list(
        page_id = page_id,
        visualization = visualization,
        controls = controls,
        validation = validation,
        current_simulation_id = current_simulation_id
    ))
}

#' Create a validation state object
#' @param is_valid Logical: overall validation state
#' @param field_states Named list of field validation states
#' @return List with validation state properties
create_validation_state <- function(
    is_valid = TRUE,
    field_states = list()) {
    validate_validation_state(list(
        is_valid = is_valid,
        field_states = field_states
    ))
}

#' Create a model state object
#' @param status Character: "loading", "loaded", or "error"
#' @param error_message Character: Error message if any
#' @return List with model state properties
create_model_state <- function(
    status = "loading",
    error_message = NULL) {
    validate_model_state(list(
        status = status,
        error_message = error_message
    ))
}

#' Validate model state object
#' @param state List containing model state properties
#' @return The state object if valid, otherwise throws error
validate_model_state <- function(state) {
    if (!is.list(state)) stop("Model state must be a list")

    # Required fields
    required <- c("status", "error_message")
    missing <- setdiff(required, names(state))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required model state fields: %s",
            paste(missing, collapse = ", ")
        ))
    }

    # Validate status
    if (!state$status %in% c("loading", "loaded", "error")) {
        stop("Invalid status value. Must be 'loading', 'loaded', or 'error'")
    }

    # Validate error_message
    if (!is.null(state$error_message) && !is.character(state$error_message)) {
        stop("error_message must be NULL or a character string")
    }

    state
}

# Validation functions

#' Validate visualization state object
#' @param state List containing visualization state properties
#' @return The state object if valid, otherwise throws error
validate_visualization_state <- function(state) {
    if (!is.list(state)) stop("Visualization state must be a list")

    # Required fields
    required <- c("visibility", "plot_status", "display_type", "error_message")
    missing <- setdiff(required, names(state))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required visualization state fields: %s",
            paste(missing, collapse = ", ")
        ))
    }

    # Validate visibility
    if (!state$visibility %in% c("visible", "hidden", "loading")) {
        stop("Invalid visibility value. Must be 'visible', 'hidden', or 'loading'")
    }

    # Validate plot_status
    if (!state$plot_status %in% c("ready", "loading", "error")) {
        stop("Invalid plot_status value. Must be 'ready', 'loading', or 'error'")
    }

    # Validate display_type
    if (!state$display_type %in% c("plot", "table")) {
        stop("Invalid display_type value. Must be 'plot' or 'table'")
    }

    # Validate error_message
    if (!is.character(state$error_message)) {
        stop("error_message must be a character string")
    }

    state
}

#' Validate control state object
#' @param state List containing control state properties
#' @return The state object if valid, otherwise throws error
validate_control_state <- function(state) {
    if (!is.list(state)) stop("Control state must be a list")

    # Required structure (not values)
    required <- c("outcomes", "facet.by", "summary.type")
    missing <- setdiff(required, names(state))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required control state fields: %s",
            paste(missing, collapse = ", ")
        ))
    }

    # Allow NULL values but validate types if present
    if (!is.null(state$outcomes) && !is.character(state$outcomes)) {
        stop("outcomes must be NULL or a character vector")
    }

    if (!is.null(state$facet.by) && !is.character(state$facet.by)) {
        stop("facet.by must be NULL or a character vector")
    }

    if (!is.null(state$summary.type)) {
        if (!is.character(state$summary.type)) {
            stop("summary.type must be a character value")
        }
        valid_summary_types <- c(
            "individual.simulation",
            "mean.and.interval",
            "median.and.interval"
        )
        if (!state$summary.type %in% valid_summary_types) {
            stop(sprintf(
                "Invalid summary.type. Must be one of: %s",
                paste(valid_summary_types, collapse = ", ")
            ))
        }
    }

    # Fix key names to match expected format
    if ("facet_by" %in% names(state)) {
        state$facet.by <- state$facet_by
        state$facet_by <- NULL
    }
    if ("summary_type" %in% names(state)) {
        state$summary.type <- state$summary_type
        state$summary_type <- NULL
    }

    state
}

#' Validate panel state object
#' @param state List containing panel state properties
#' @return The state object if valid, otherwise throws error
validate_panel_state <- function(state) {
    if (!is.list(state)) stop("Panel state must be a list")

    # Required fields
    required <- c("page_id", "visualization", "controls", "validation", "current_simulation_id")
    missing <- setdiff(required, names(state))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required panel state fields: %s",
            paste(missing, collapse = ", ")
        ))
    }

    # Validate page_id
    if (!state$page_id %in% c("prerun", "custom")) {
        stop("page_id must be either 'prerun' or 'custom'")
    }

    # Validate current_simulation_id
    if (!is.null(state$current_simulation_id) &&
        (!is.character(state$current_simulation_id) || length(state$current_simulation_id) != 1)) {
        stop("current_simulation_id must be NULL or a single character string")
    }

    # Validate nested states
    state$visualization <- validate_visualization_state(state$visualization)
    state$controls <- validate_control_state(state$controls)
    state$validation <- validate_validation_state(state$validation)

    state
}

#' Validate validation state object
#' @param state List containing validation state properties
#' @return The state object if valid, otherwise throws error
validate_validation_state <- function(state) {
    if (!is.list(state)) stop("Validation state must be a list")

    # Required fields
    required <- c("is_valid", "field_states")
    missing <- setdiff(required, names(state))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required validation state fields: %s",
            paste(missing, collapse = ", ")
        ))
    }

    # Type checking
    if (!is.logical(state$is_valid)) {
        stop("is_valid must be logical")
    }
    if (!is.list(state$field_states)) {
        stop("field_states must be a list")
    }

    state
}
