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

    # Extract location and subgroups
    location <- settings$location
    subgroups <- settings$subgroups

    # Generate intervention code base (max 25 chars)
    timestamp <- format(Sys.time(), "%m%d%H%M") # Shorter timestamp: MMDDHHMM
    intervention_code_base <- if (!is.null(session_id)) {
        # Take first 8 chars of session id if it's longer
        short_session <- substr(session_id, 1, 8)
        paste0("c.", short_session, ".", timestamp) # c.12345678.02051123
    } else {
        paste0("c.", timestamp) # c.02051123
    }

    # If no subgroups have enabled interventions, return null intervention
    if (!any(sapply(subgroups, function(sg) {
        any(sapply(sg$interventions[names(MODEL_EFFECTS)], function(int) isTRUE(int$enabled)))
    }))) {
        return(jheem2:::get.null.intervention())
    }

    # Get dimension configurations
    config <- get_defaults_config()
    dimensions <- names(config$model_dimensions)

    # Create an intervention for each subgroup
    subgroup_interventions <- list()

    for (subgroup in subgroups) {
        # Skip if no enabled interventions
        if (!any(sapply(subgroup$interventions[names(MODEL_EFFECTS)], function(int) isTRUE(int$enabled)))) {
            next
        }

        # Map UI demographic values to model values for each dimension
        demographics <- list()
        name_parts <- c()

        for (dim in dimensions) {
            # Get UI field name from config
            ui_field <- config$model_dimensions[[dim]]$ui_field

            # Get values if they exist
            ui_values <- subgroup$demographics[[ui_field]]
            if (!is.null(ui_values) && length(ui_values) > 0) {
                # Map each UI value to model value
                model_values <- sapply(ui_values, function(val) {
                    get_model_dimension_value(dim, val)
                })
                demographics[[dim]] <- model_values

                # Add to name parts
                name_parts <- c(
                    name_parts,
                    if (length(model_values) > 1) {
                        paste0(model_values[1], ".", length(model_values))
                    } else {
                        model_values[1]
                    }
                )
            }
        }

        # Create target name
        target_name <- paste(name_parts, collapse = ".")
        if (nchar(target_name) > 25) {
            target_name <- paste0(substr(target_name, 1, 22), "...")
        }
        # Replace underscores with dashes in the name only
        target_name <- gsub("_", "-", target_name)

        # Create target population with mapped demographics
        target_args <- list(name = target_name)
        for (dim in names(demographics)) {
            target_args[[dim]] <- demographics[[dim]]
        }
        target_pop <- do.call(create.target.population, target_args)

        # Create effects for this subgroup
        subgroup_effects <- list()
        for (intervention_type in names(MODEL_EFFECTS)) {
            if (isTRUE(subgroup$interventions[[intervention_type]]$enabled)) {
                effect_config <- get_effect_config(intervention_type)
                value <- subgroup$interventions[[intervention_type]][[effect_config$value_field]]

                effect <- effect_config$create(
                    start_time = as.numeric(subgroup$interventions$dates$start),
                    end_time = as.numeric(subgroup$interventions$dates$end),
                    value = value
                )
                subgroup_effects[[length(subgroup_effects) + 1]] <- effect
            }
        }

        # Create intervention for this subgroup with unique code
        if (length(subgroup_effects) > 0) {
            subgroup_code <- paste0(intervention_code_base, ".", length(subgroup_interventions))
            subgroup_interventions[[length(subgroup_interventions) + 1]] <-
                create.intervention(target_pop, subgroup_effects,
                    code = subgroup_code,
                    overwrite.existing.intervention = TRUE
                )
        }
    }

    # Return combined intervention or null intervention
    if (length(subgroup_interventions) > 0) {
        if (length(subgroup_interventions) == 1) {
            subgroup_interventions[[1]]
        } else {
            # Join all subgroup interventions with unique code
            join.interventions(
                subgroup_interventions,
                code = intervention_code_base,
                overwrite.existing.intervention = TRUE
            )
        }
    } else {
        jheem2:::get.null.intervention()
    }
}

#' Get a prerun intervention based on settings
#' @param settings List of settings from UI
#' @return jheem intervention object
get_prerun_intervention <- function(settings) {
    stop("Prerun interventions not yet implemented")
}
