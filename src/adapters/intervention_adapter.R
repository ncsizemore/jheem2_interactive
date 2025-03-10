source("src/adapters/interventions/model_effects.R")

#' Check if a component is a compound component
#' @param component Component to check
#' @return TRUE if component is compound, FALSE otherwise
is_compound_component <- function(component) {
  return(!is.null(component$type) && component$type == "compound")
}

#' Get component value based on type
#' @param component Component to get value from
#' @return Component value or NULL if disabled
get_component_value <- function(component) {
  if (is_compound_component(component)) {
    if (!component$enabled) {
      return(NULL)  # Return NULL for disabled components
    }
    # For compound components, value should already be extracted
    if (is.null(component$value)) {
      print("WARNING: Enabled compound component has NULL value")
      print("Full component structure:")
      str(component)
    }
    return(component$value)
  } else if (is.list(component) && !is.null(component$value)) {
    # Handle component as a list with value field
    return(component$value)
  } else {
    # Handle simple value (likely numeric)
    return(component)
  }
}

#' Create an intervention from UI settings
#' @param settings List of settings from UI
#' @param mode Either "prerun" or "custom"
#' @param session_id Unique session identifier from Shiny
#' @return jheem intervention object
create_intervention <- function(settings, mode = c("prerun", "custom"), session_id = NULL) {
  mode <- match.arg(mode)
  print("=== create_intervention ===")
  print(paste("Mode:", mode))
  print("Settings:")
  str(settings)
  
  if (mode == "custom") {
    create_custom_intervention(settings, session_id)
  } else {
    get_prerun_intervention(settings)
  }
}

#' Create a custom intervention from UI settings
#' @param settings List of settings from UI
#' @param session_id Optional session identifier
#' @return jheem intervention object
create_custom_intervention <- function(settings, session_id = NULL) {
  print("Creating custom intervention with settings:")
  str(settings)
  
  # Extract components
  components_list <- settings$components
  
  # Check model-specific behavior (from model_effects.R)
  use_whole_population <- uses_whole_population()
  supports_subgroups <- supports_subgroup_targeting()
  
  print(paste("Model configuration - use_whole_population:", use_whole_population))
  print(paste("Model configuration - supports_subgroups:", supports_subgroups))
  
  # Generate intervention code base (max 25 chars)
  timestamp <- format(Sys.time(), "%m%d%H%M") # Shorter timestamp: MMDDHHMM
  intervention_code_base <- if (!is.null(session_id)) {
    # Take first 8 chars of session id if it's longer
    short_session <- substr(session_id, 1, 8)
    paste0("c.", short_session, ".", timestamp) # c.12345678.02051123
  } else {
    paste0("c.", timestamp) # c.02051123
  }
  
  # Return null intervention if no components
  if (is.null(components_list) || length(components_list) == 0) {
    print("No components found, returning null intervention")
    return(jheem2:::get.null.intervention())
  }
  
  # Initialize lists to track created things
  all_effects <- list()
  group_interventions <- list()
  
  # Process components
  for (group_idx in seq_along(components_list)) {
    group_components <- components_list[[group_idx]]
    
    # Skip if no components
    if (length(group_components) == 0) {
      next
    }
    
    for (component in group_components) {
      # Skip NULL components (disabled components from compound inputs)
      if (is.null(component)) {
        print("Skipping NULL component")
        next
      }
      
      # Skip disabled components
      if (is.list(component) && !is.null(component$enabled) && !component$enabled) {
        print("Skipping disabled component")
        next
      }
      
      # Get group ID and component type
      group_id <- component$group
      component_type <- component$type
      
      # Debug output
      print("Component details:")
      print(paste("  Type:", component_type))
      print(paste("  Group ID:", group_id))
      print(paste("  Enabled:", ifelse(is.list(component) && !is.null(component$enabled), component$enabled, "N/A")))
      
      # Validation for group ID
      if (is.null(group_id) || length(group_id) == 0 || !is.character(group_id)) {
        warning("Invalid group ID - must be a non-empty character string")
        next
      }
      
      # Get appropriate effect configuration
      effect_config <- tryCatch({
        get_effect_config(component_type, group_id)
      }, error = function(e) {
        warning(paste(
          "Unknown effect type:", component_type, "for group", group_id, "\n",
          "Available effects:", paste(names(MODEL_EFFECTS), collapse=", ")
        ))
        NULL
      })
      
      # Skip if no effect configuration found
      if (is.null(effect_config)) {
        next
      }
      
      # Get actual value from component
      actual_value <- get_component_value(component)
      print(paste("Using actual value for effect:", actual_value))
      
      # Create effect
      effect <- tryCatch({
        effect_config$create(
          start_time = as.numeric(settings$dates$start),
          end_time = as.numeric(settings$dates$end),
          value = actual_value,
          group_id = group_id
        )
      }, error = function(e) {
        warning(paste("Error creating effect:", e$message))
        NULL
      })
      
      # Skip if effect creation failed
      if (is.null(effect)) {
        warning("Failed to create effect, skipping component")
        next
      }
      
      # Add to all effects list
      all_effects[[length(all_effects) + 1]] <- effect
      
      # If using subgroup targeting, create separate interventions
      if (!use_whole_population && supports_subgroups) {
        # Create target population for this group
        target_name <- gsub("_", "-", group_id)
        target_pop <- create.target.population(name = target_name)
        
        print(paste("Creating targeted intervention for group:", group_id))
        
        # Create intervention for this effect and target
        intervention_code <- paste0(intervention_code_base, ".", length(group_interventions))
        
        # Create intervention with target population first
        tryCatch({
          int <- create.intervention(
            target_pop,  # Target population first
            effect,      # Then effect
            code = intervention_code,
            overwrite.existing.intervention = TRUE
          )
          
          # Add to list of interventions
          group_interventions[[length(group_interventions) + 1]] <- int
          print(paste("Successfully created targeted intervention for group:", group_id))
        }, error = function(e) {
          warning(paste("Error creating targeted intervention:", e$message))
        })
      }
    }
  }
  
  # Count the effects and interventions created
  print(paste("Created", length(all_effects), "effects total"))
  if (!use_whole_population && supports_subgroups) {
    print(paste("Created", length(group_interventions), "targeted interventions"))
  }
  
  # Return null intervention if no effects
  if (length(all_effects) == 0) {
    print("No valid effects created, returning null intervention")
    return(jheem2:::get.null.intervention())
  }
  
  # Create final intervention based on model approach
  if (use_whole_population) {
    # Whole population approach (Ryan White)
    print("Using whole population approach for intervention creation")
    
    # Create a single intervention with all effects and WHOLE.POPULATION
    return(tryCatch({
      # Ensure WHOLE.POPULATION exists
      if (!exists("WHOLE.POPULATION", envir = .GlobalEnv)) {
        WHOLE.POPULATION <<- create.target.population(name = 'Whole Population')
        print("Created global WHOLE.POPULATION target")
      }
      
      combined_code <- paste0("all.", intervention_code_base)
      print(paste("Creating combined intervention with code:", combined_code))
      
      # Construct arguments list with WHOLE.POPULATION first, then all effects
      args <- c(
        list(WHOLE.POPULATION),  # WHOLE.POPULATION first
        all_effects,             # Then all effects
        list(
          code = combined_code,
          overwrite.existing.intervention = TRUE
        )
      )
      
      # Create intervention
      result <- do.call(create.intervention, args)
      print("Successfully created combined intervention")
      result
    }, error = function(e) {
      warning(paste("Error creating combined intervention:", e$message))
      jheem2:::get.null.intervention()
    }))
  } else if (length(group_interventions) > 0) {
    # Subgroup targeting approach (EHE)
    print("Using subgroup targeting approach for intervention creation")
    
    # Return the joined intervention
    if (length(group_interventions) == 1) {
      print("Returning single targeted intervention")
      return(group_interventions[[1]])
    } else {
      joined_code <- paste0("joined.", intervention_code_base)
      print(paste("Joining", length(group_interventions), "interventions with code:", joined_code))
      
      return(tryCatch({
        joined <- join.interventions(
          group_interventions,
          code = joined_code,
          overwrite.existing.intervention = TRUE
        )
        print("Successfully joined interventions")
        joined
      }, error = function(e) {
        warning(paste("Error joining interventions:", e$message))
        # Return first intervention as fallback
        if (length(group_interventions) > 0) {
          group_interventions[[1]]
        } else {
          jheem2:::get.null.intervention()
        }
      }))
    }
  } else {
    # Fallback - create with WHOLE.POPULATION
    print("Using fallback approach - creating whole population intervention")
    
    return(tryCatch({
      # Ensure WHOLE.POPULATION exists
      if (!exists("WHOLE.POPULATION", envir = .GlobalEnv)) {
        WHOLE.POPULATION <<- create.target.population(name = 'Whole Population')
        print("Created global WHOLE.POPULATION target")
      }
      
      fallback_code <- paste0("fallback.", intervention_code_base)
      
      args <- c(
        list(WHOLE.POPULATION),
        all_effects,
        list(
          code = fallback_code,
          overwrite.existing.intervention = TRUE
        )
      )
      
      do.call(create.intervention, args)
    }, error = function(e) {
      warning(paste("Error creating fallback intervention:", e$message))
      jheem2:::get.null.intervention()
    }))
  }
}

#' Get a prerun intervention based on settings
#' @param settings List of settings from UI
#' @return jheem intervention object
get_prerun_intervention <- function(settings) {
  stop("Prerun interventions not yet implemented")
}
