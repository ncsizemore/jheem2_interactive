# src/ui/components/common/layout/section_builder.R

# Source dependencies
source("src/ui/components/common/errors/boundaries.R")
source("src/ui/components/common/errors/handlers.R")
source("src/ui/components/common/display/section_header.R")

#' Creates sections based on configuration with error handling
#' @param config Page configuration
#' @param page_type Page type (prerun or custom)
#' @param session Optional Shiny session object for error handling
#' @param output Optional Shiny output object for error handling
#' @return List of section elements
create_sections_from_config <- function(config, page_type, session = NULL, output = NULL) {
  # Create an error boundary if session and output are provided
  error_boundary <- if (!is.null(session) && !is.null(output)) {
    create_error_boundary(
      session = session,
      output = output,
      page_id = page_type,
      id = paste0("section_builder_", page_type)
    )
  } else {
    NULL
  }
  
  # Create error text ID for direct error display
  error_text_id <- paste0(page_type, "_section_error")
  
  # Set up the result variable outside tryCatch
  result <- NULL
  
  # Try to build sections with error handling
  tryCatch({
    # Clear any existing errors if we have a boundary
    if (!is.null(error_boundary)) {
      error_boundary$clear_error()
      
      # Clear direct error output if we have output
      if (!is.null(output)) {
        output[[error_text_id]] <- renderText({ NULL })
      }
    }
    
    # Build sections
    result <- build_sections_internal(config, page_type)
  }, 
  error = function(e) {
    # Prepare error message
    error_message <- paste("Error creating UI sections:", conditionMessage(e))
    
    # Log the error
    warning(error_message)
    
    # Set error in boundary if we have one
    if (!is.null(error_boundary)) {
      set_component_error(
        boundary = error_boundary,
        output = output,
        error_id = error_text_id,
        message = error_message,
        type = ERROR_TYPES$SYSTEM,
        severity = SEVERITY_LEVELS$ERROR,
        details = as.character(e)
      )
    }
    
    # Create fallback sections
    result <<- create_fallback_sections(config, page_type)
  })
  
  # Return sections with error display if we have a boundary
  if (!is.null(error_boundary) && !is.null(output)) {
    # Add error displays to the result
    result$error_displays <- tagList(
      # Direct error display
      tags$div(
        class = "section-error error",
        textOutput(error_text_id, inline = FALSE)
      ),
      
      # Error boundary display
      uiOutput(paste0(page_type, "_section_builder_", page_type, "_error_display"))
    )
  }
  
  return(result)
}

#' Validate section configuration
#' @param config Section configuration
#' @return TRUE if valid, throws error if invalid
validate_section_config <- function(config) {
  if (is.null(config$sections)) {
    return(TRUE)  # No sections defined is valid
  }
  
  for (section_id in names(config$sections)) {
    section <- config$sections[[section_id]]
    
    # Check for required fields
    if (is.null(section$title)) {
      warning(sprintf("Section '%s' is missing a title", section_id))
    }
    
    # Validate selectors if present
    if (!is.null(section$selectors) && !is.vector(section$selectors)) {
      stop(sprintf("Section '%s' has invalid selectors (must be a vector)", section_id))
    }
  }
  
  TRUE
}

#' Internal function to build sections
#' @param config Page configuration
#' @param page_type Page type (prerun or custom)
#' @return List of section elements
build_sections_internal <- function(config, page_type) {
  sections <- list()
  
  # Validate configuration
  validate_section_config(config)
  
  # First, get all configured selectors
  all_selectors <- names(config$selectors)
  assigned_selectors <- c()
  
  # Create sections defined in the config
  if (!is.null(config$sections)) {
    for (section_id in names(config$sections)) {
      section_config <- config$sections[[section_id]]
      section_selectors <- section_config$selectors %||% c()
      
      # Only add sections that have at least one valid selector
      valid_selectors <- list()
      for (selector_id in section_selectors) {
        selector <- if (selector_id == "location") {
          create_location_selector(page_type)
        } else {
          create_selector(selector_id, page_type)
        }
        
        if (!is.null(selector)) {
          valid_selectors[[length(valid_selectors) + 1]] <- selector
          assigned_selectors <- c(assigned_selectors, selector_id)
        }
      }
      
      # Only add section if it has valid selectors
      if (length(valid_selectors) > 0) {
        sections[[section_id]] <- tagList(
          create_section_header(section_config$title, section_config$description),
          valid_selectors
        )
      }
    }
  }
  
  # Create automatic sections for special selectors that aren't already assigned
  
  # Location section (if not already in a section)
  if (!("location" %in% assigned_selectors) && !is.null(create_location_selector(page_type))) {
    location_config <- config$sections$location %||% list(title = "Location", description = "Select the geographic area for the model")
    sections["location"] <- tagList(
      create_section_header(location_config$title, location_config$description),
      create_location_selector(page_type)
    )
    assigned_selectors <- c(assigned_selectors, "location")
  }
  
  # Intervention sections (if not already assigned)
  intervention_selectors <- c("intervention_aspects", "population_groups", "timeframes", "intensities")
  unassigned_intervention_selectors <- setdiff(intervention_selectors, assigned_selectors)
  
  if (length(unassigned_intervention_selectors) > 0 && !is.null(config$intervention_aspects)) {
    valid_int_selectors <- list()
    
    # Try to create each intervention selector
    for (selector_id in intervention_selectors) {
      if (selector_id == "intervention_aspects") {
        selector <- create_intervention_selector(page_type)
      } else if (selector_id == "population_groups") {
        selector <- create_population_selector(page_type)
      } else if (selector_id == "timeframes") {
        selector <- create_timeframe_selector(page_type)
      } else if (selector_id == "intensities") {
        selector <- create_intensity_selector(page_type)
      }
      
      if (!is.null(selector)) {
        valid_int_selectors[[length(valid_int_selectors) + 1]] <- selector
      }
    }
    
    # Only add intervention section if it has valid selectors
    if (length(valid_int_selectors) > 0) {
      intervention_config <- config$sections$intervention %||% list(title = "Intervention", description = "Choose intervention parameters")
      sections["intervention"] <- tagList(
        create_section_header(intervention_config$title, intervention_config$description),
        valid_int_selectors
      )
      assigned_selectors <- c(assigned_selectors, unassigned_intervention_selectors)
    }
  }
  
  # Create a fallback section for any remaining unassigned selectors
  remaining_selectors <- setdiff(all_selectors, assigned_selectors)
  if (length(remaining_selectors) > 0) {
    fallback_selectors <- list()
    
    for (selector_id in remaining_selectors) {
      selector <- create_selector(selector_id, page_type)
      if (!is.null(selector)) {
        fallback_selectors[[length(fallback_selectors) + 1]] <- selector
      }
    }
    
    if (length(fallback_selectors) > 0) {
      sections["other"] <- tagList(
        create_section_header("Additional Settings", "Other configuration options"),
        fallback_selectors
      )
    }
  }
  
  return(sections)
}

#' Create fallback sections for error recovery
#' @param config Page configuration
#' @param page_type Page type (prerun or custom)
#' @return Simple section with available selectors
create_fallback_sections <- function(config, page_type) {
  # Create a simple fallback with location and any directly configured selectors
  fallback_selectors <- list()
  
  # Try to add location
  location_selector <- create_location_selector(page_type)
  if (!is.null(location_selector)) {
    fallback_selectors[[length(fallback_selectors) + 1]] <- location_selector
  }
  
  # Try to add any configured selectors directly
  if (!is.null(config$selectors)) {
    for (selector_id in names(config$selectors)) {
      # Skip location as we already tried it
      if (selector_id == "location") next
      
      selector <- create_selector(selector_id, page_type)
      if (!is.null(selector)) {
        fallback_selectors[[length(fallback_selectors) + 1]] <- selector
      }
    }
  }
  
  # Return a basic section structure with error notice
  list(
    fallback = tagList(
      tags$div(
        class = "error-recovery-fallback",
        style = "border-top: 1px solid #dc3545; padding-top: 10px; margin-top: 10px;",
        tags$div(
          class = "fallback-notice",
          style = "color: #856404; background-color: #fff3cd; padding: 10px; margin-bottom: 15px; border-radius: 4px;",
          "Using basic interface due to configuration error."
        ),
        fallback_selectors
      )
    )
  )
}
