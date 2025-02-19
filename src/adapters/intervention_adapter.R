source("src/adapters/interventions/model_effects.R")

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
                next
            }
            
            # Get group ID and component type
            group_id <- component$group
            component_type <- component$type
            component_value <- component$value
            
            print(paste("Processing component:", component_type, "for group:", group_id, "with value:", component_value))
            
            # Create target population for this group
            # Replace underscores with dashes for compliance with naming restrictions
            target_name <- gsub("_", "-", group_id)
            target_pop <- create.target.population(
                name = target_name
            )
            
            # Try to find direct effect mapping first
            # We keep group_id with underscores for effect mapping
            direct_effect_name <- paste0(group_id, "_", component_type)
            
            # Determine which effect configuration to use
            if (direct_effect_name %in% names(MODEL_EFFECTS)) {
                effect_config <- MODEL_EFFECTS[[direct_effect_name]]
                print(paste("Using direct effect:", direct_effect_name))
            } else if (component_type %in% names(MODEL_EFFECTS)) {
                # Try generic effect
                effect_config <- MODEL_EFFECTS[[component_type]]
                print(paste("Using generic effect:", component_type))
            } else {
                warning(paste(
                    "Unknown effect type:", component_type, "for group", group_id, "\n",
                    "Tried direct effect name:", direct_effect_name, "\n",
                    "Available effects:", paste(names(MODEL_EFFECTS), collapse=", ")
                ))
                next
            }
            
            # Create effect
            effect <- effect_config$create(
                start_time = as.numeric(settings$dates$start),
                end_time = as.numeric(settings$dates$end),
                value = component_value,
                group_id = group_id
            )
            
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
        if (length(group_interventions) == 1) {
            group_interventions[[1]]
        } else {
            # Join all group interventions with unique code
            join.interventions(
                group_interventions,
                code = intervention_code_base,
                overwrite.existing.intervention = TRUE
            )
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
