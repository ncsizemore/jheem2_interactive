# First, source the section header component
source("src/ui/components/common/display/section_header.R")

#' Creates sections based on configuration
#' @param config Page configuration
#' @param page_type Page type (prerun or custom)
#' @return List of section elements
create_sections_from_config <- function(config, page_type) {
  sections <- list()
  
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

#' Creates the intervention panel content
#' @param config Page configuration
create_intervention_content <- function(config) {
    # Create sections based on configuration
    sections <- create_sections_from_config(config, "prerun")
    
    tagList(
        # Selectors container
        tags$div(
            class = "intervention-options",
            # Spread the sections
            sections,

            # Generate button using config settings
            tags$div(
                class = "generate-controls",
                actionButton(
                    inputId = "generate_projections_prerun",
                    label = config$defaults$buttons$generate$label,
                    class = paste(
                        "btn",
                        config$theme$buttons$primary_class
                    )
                ),

                # Feedback area using config
                tags$div(
                    class = "generate-feedback",
                    tags$small(config$defaults$feedback$generate$message),
                    if (config$defaults$feedback$generate$show_chime) {
                        tags$div(
                            class = "chime-option",
                            checkboxInput(
                                "chime_prerun",
                                config$defaults$feedback$generate$chime_label,
                                value = FALSE
                            )
                        )
                    }
                )
            )
        )
    )
}

#' Creates the plot controls for the right panel
#' @param config Page configuration
create_prerun_plot_controls <- function(config) {
    print("=== Creating Prerun Plot Controls ===")

    # Update source path
    source("src/ui/components/common/plot_controls/control_section.R")

    plot_config <- config$plot_controls

    # Create namespace for this module
    ns <- NS("prerun")

    tagList(
        # Outcomes section
        create_control_section(
            type = "outcomes",
            config = plot_config$outcomes,
            suffix = "prerun",
            ns = ns
        ),

        # Stratification section
        create_control_section(
            type = "stratification",
            config = plot_config$stratification,
            suffix = "prerun",
            ns = ns
        ),

        # Display options section
        create_control_section(
            type = "display",
            config = plot_config$display,
            suffix = "prerun",
            ns = ns
        )
    )
}