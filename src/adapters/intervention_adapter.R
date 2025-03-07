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
        # If value is NULL but component is enabled, try to debug
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

    # Extract location and components
    location <- settings$location
    components_list <- settings$components
    
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
    
    # Create an intervention for each component group
    group_interventions <- list()
    
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
            
            # Get group ID and component type with better error checking
            group_id <- component$group
            component_type <- component$type
            component_value <- component$value
            
            # Enhanced debug output
            print("Component details:")
            print(paste("  Type:", component_type))
            print(paste("  Group ID:", group_id))
            print(paste("  Value:", component_value))
            print(paste("  Enabled:", component$enabled))
            print("Full component structure:")
            str(component)
            
            # Validation for group ID
            if (is.null(group_id) || length(group_id) == 0 || !is.character(group_id)) {
                warning("Invalid group ID - must be a non-empty character string")
                next
            }
            
            # Create target population for this group
            # Replace underscores with dashes for compliance with naming restrictions
            target_name <- gsub("_", "-", group_id)
            target_pop <- create.target.population(
                name = target_name
            )
            
            # Get appropriate effect configuration using enhanced function
            # This will try both direct and generic effects
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
            
            # Create effect
            effect <- tryCatch({
                # Get actual value from component (handles different formats)
                actual_value <- get_component_value(component)
                print(paste("Using actual value for effect:", actual_value))
                
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
            
            # Create intervention with unique code
            intervention_code <- paste0(intervention_code_base, ".", length(group_interventions))
            group_interventions[[length(group_interventions) + 1]] <- create.intervention(
                target_pop, 
                list(effect),
                code = intervention_code,
                overwrite.existing.intervention = TRUE
            )
        }
    }
    
    # Return combined intervention or null intervention
    if (length(group_interventions) > 0) {
        print(paste("Created", length(group_interventions), "interventions"))
        print("SIMPLIFIED: Using only the first intervention (adap) for testing")
        # Just return the first intervention for testing
        if (length(group_interventions) >= 1) {
            return(group_interventions[[1]])
        } else {
            print("No valid interventions created, returning null intervention")
            return(jheem2:::get.null.intervention())
        }
    } else {
        print("No valid interventions created, returning null intervention")
        jheem2:::get.null.intervention()
    }
}

#' Get a prerun intervention based on settings
#' @param settings List of settings from UI
#' @return jheem intervention object
get_prerun_intervention <- function(settings) {
    stop("Prerun interventions not yet implemented")
}
