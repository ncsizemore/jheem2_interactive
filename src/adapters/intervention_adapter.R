#' Create an intervention from UI settings
#' @param settings List of settings from UI
#' @param mode Either "prerun" or "custom"
#' @param session_id Unique session identifier from Shiny
#' @return jheem intervention object
create_intervention <- function(settings, mode = c("prerun", "custom"), session_id = NULL) {
    mode <- match.arg(mode)

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

    # Create an intervention for each subgroup
    subgroup_interventions <- list()

    for (subgroup in subgroups) {
        # Skip if no enabled interventions
        if (!any(sapply(subgroup$interventions[names(MODEL_EFFECTS)], function(int) isTRUE(int$enabled)))) {
            next
        }

        # Filter out NULL demographics and create name components
        demographics <- list()
        name_parts <- c()

        for (dim in names(subgroup$demographics)) {
            vals <- subgroup$demographics[[dim]]
            if (!is.null(vals) && length(vals) > 0) {
                demographics[[dim]] <- vals
                name_parts <- c(
                    name_parts,
                    if (length(vals) > 1) {
                        paste0(vals[1], ".", length(vals))
                    } else {
                        vals[1]
                    }
                )
            }
        }

        # Create target name
        target_name <- paste(name_parts, collapse = ".")
        if (nchar(target_name) > 25) {
            target_name <- paste0(substr(target_name, 1, 22), "...")
        }

        # Create target population with non-NULL demographics
        target_args <- list(name = target_name)
        if (length(demographics$age_groups) > 0) target_args$age <- demographics$age_groups
        if (length(demographics$race_ethnicity) > 0) target_args$race <- demographics$race_ethnicity
        if (length(demographics$biological_sex) > 0) target_args$sex <- demographics$biological_sex
        if (length(demographics$risk_factor) > 0) target_args$risk <- demographics$risk_factor

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
            subgroup_code <- paste0(intervention_code_base, ".", length(subgroup_interventions)) # Just use number
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
