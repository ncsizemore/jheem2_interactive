#' Model-specific intervention effect configurations
#' @description Defines how UI intervention settings map to model effects

#' Create a standard intervention effect
#' @param quantity_name Name of the quantity to affect or function to dynamically determine quantity
#' @param scale Type of scale (proportion or rate)
#' @param start_time Start year
#' @param end_time End year
#' @param value Effect value
#' @param transform Function to transform value (optional)
#' @param group_id Group identifier for dynamic quantity determination (optional)
#' @return jheem intervention effect
create_standard_effect <- function(quantity_name, scale, start_time, end_time, value, transform = NULL, group_id = NULL) {
    # Handle dynamic quantity names based on group_id
    if (is.function(quantity_name)) {
        quantity_name <- quantity_name(group_id)
    }
    
    # Apply transformation if provided
    effect_value <- if (!is.null(transform) && is.function(transform)) {
        transform(value)
    } else {
        value
    }

    create.intervention.effect(
        quantity.name = quantity_name,
        start.time = start_time,
        effect.values = effect_value,
        apply.effects.as = "value",
        scale = scale,
        times = end_time,
        allow.values.less.than.otherwise = FALSE,
        allow.values.greater.than.otherwise = TRUE
    )
}

#' Get effect configuration for an intervention type
#' @param intervention_type The type of intervention
#' @param group_id Optional group identifier for specific lookups
#' @return List of effect configuration parameters
get_effect_config <- function(intervention_type, group_id = NULL) {
    # Try to get component-specific effect
    if (!intervention_type %in% names(MODEL_EFFECTS)) {
        # Try a group-specific lookup if provided
        if (!is.null(group_id)) {
            # Construct potential group-specific key
            group_specific_key <- paste0(group_id, "_", intervention_type)
            if (group_specific_key %in% names(MODEL_EFFECTS)) {
                return(MODEL_EFFECTS[[group_specific_key]])
            }
        }
        stop(sprintf("Unknown intervention type: %s", intervention_type))
    }
    MODEL_EFFECTS[[intervention_type]]
}

#' Convert percentage to proportion
#' @param value Percentage value
#' @return Proportion value
percentage_to_proportion <- function(value) value / 100

#' Model effect configurations
MODEL_EFFECTS <- list(
    prep = list(
        quantity_name = "oral.prep.uptake",
        scale = "proportion",
        transform = percentage_to_proportion,
        value_field = "coverage",
        create = function(start_time, end_time, value, group_id = NULL) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$prep$quantity_name,
                scale = MODEL_EFFECTS$prep$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$prep$transform,
                group_id = group_id
            )
        }
    ),
    testing = list(
        quantity_name = "general.population.testing",
        scale = "rate",
        transform = function(value) as.numeric(value), # Ensure numeric conversion
        value_field = "frequency",
        create = function(start_time, end_time, value, group_id = NULL) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$testing$quantity_name,
                scale = MODEL_EFFECTS$testing$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$testing$transform,
                group_id = group_id
            )
        }
    ),
    suppression = list(
        quantity_name = "suppression.of.diagnosed",
        scale = "proportion",
        transform = percentage_to_proportion,
        value_field = "proportion",
        create = function(start_time, end_time, value, group_id = NULL) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$suppression$quantity_name,
                scale = MODEL_EFFECTS$suppression$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$suppression$transform,
                group_id = group_id
            )
        }
    )
)
