#' Create an intervention from UI settings
#' @param settings List of settings from UI
#' @param mode Either "prerun" or "custom"
#' @return jheem intervention object
create_intervention <- function(settings, mode = c("prerun", "custom")) {
    mode <- match.arg(mode)

    if (mode == "custom") {
        create_custom_intervention(settings)
    } else {
        get_prerun_intervention(settings)
    }
}

#' Create a custom intervention from UI settings
#' @param settings List of settings from UI
#' @return jheem intervention object
create_custom_intervention <- function(settings) {
    # Extract location and subgroups
    location <- settings$location
    subgroups <- settings$subgroups

    # If no subgroups have enabled interventions, return null intervention
    if (!any(sapply(subgroups, function(sg) {
        any(sapply(sg$interventions[names(MODEL_EFFECTS)], function(int) isTRUE(int$enabled)))
    }))) {
        return(jheem2:::get.null.intervention())
    }

    # For now, just use the first subgroup that has enabled interventions
    # TODO: Handle multiple subgroups properly
    for (subgroup in subgroups) {
        # Check if this subgroup has any enabled interventions
        if (any(sapply(subgroup$interventions[names(MODEL_EFFECTS)], function(int) isTRUE(int$enabled)))) {
            # Create target population
            target_name <- "Target Population"
            target_pop <- create.target.population(name = target_name)

            # Collect effects for this subgroup
            effects <- list()
            for (intervention_type in names(MODEL_EFFECTS)) {
                if (isTRUE(subgroup$interventions[[intervention_type]]$enabled)) {
                    effect_config <- get_effect_config(intervention_type)
                    # Get the value using the configured field name
                    value <- subgroup$interventions[[intervention_type]][[effect_config$value_field]]

                    effect <- effect_config$create(
                        start_time = as.numeric(subgroup$interventions$dates$start),
                        end_time = as.numeric(subgroup$interventions$dates$end),
                        value = value
                    )
                    effects[[length(effects) + 1]] <- effect
                }
            }

            # Return intervention for this subgroup
            return(create.intervention(target_pop, effects))
        }
    }

    # If no subgroups had enabled interventions
    jheem2:::get.null.intervention()
}

#' Get a prerun intervention based on settings
#' @param settings List of settings from UI
#' @return jheem intervention object
get_prerun_intervention <- function(settings) {
    stop("Prerun interventions not yet implemented")
}
