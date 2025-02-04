#' Model-specific intervention effect configurations
#' @description Defines how UI intervention settings map to model effects

#' Create a standard intervention effect
#' @param quantity_name Name of the quantity to affect
#' @param scale Type of scale (proportion or rate)
#' @param start_time Start year
#' @param end_time End year
#' @param value Effect value
#' @param transform Function to transform value (optional)
#' @return jheem intervention effect
create_standard_effect <- function(quantity_name, scale, start_time, end_time, value, transform = NULL) {
    effect_value <- if (!is.null(transform)) transform(value) else value

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
#' @return List of effect configuration parameters
get_effect_config <- function(intervention_type) {
    if (!intervention_type %in% names(MODEL_EFFECTS)) {
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
        create = function(start_time, end_time, value) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$prep$quantity_name,
                scale = MODEL_EFFECTS$prep$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$prep$transform
            )
        }
    ),
    testing = list(
        quantity_name = "general.population.testing",
        scale = "rate",
        transform = function(value) value,
        value_field = "frequency",
        create = function(start_time, end_time, value) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$testing$quantity_name,
                scale = MODEL_EFFECTS$testing$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$testing$transform
            )
        }
    ),
    suppression = list(
        quantity_name = "suppression.of.diagnosed",
        scale = "proportion",
        transform = percentage_to_proportion,
        value_field = "proportion",
        create = function(start_time, end_time, value) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$suppression$quantity_name,
                scale = MODEL_EFFECTS$suppression$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$suppression$transform
            )
        }
    )
)
