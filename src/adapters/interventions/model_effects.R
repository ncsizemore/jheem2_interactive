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
        apply.effects.as = "multiplier",
        scale = scale,
        times = end_time,
        allow.values.less.than.otherwise = TRUE,
        allow.values.greater.than.otherwise = FALSE
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

#' Model effect configurations
MODEL_EFFECTS <- list(
    adap_suppression_loss = list(
        quantity_name = "adap.suppression.effect",
        scale = "proportion",
        transform = function(value) {
            # Convert percentage loss to multiplier
            # e.g., 25% loss becomes 0.75 multiplier
            1 - (value / 100)
        },
        value_field = "adap_suppression_loss",
        create = function(start_time, end_time, value) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$adap_suppression_loss$quantity_name,
                scale = MODEL_EFFECTS$adap_suppression_loss$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$adap_suppression_loss$transform
            )
        }
    ),
    non_adap_suppression_loss = list(
        quantity_name = "rw.without.adap.suppression.effect",
        scale = "proportion",
        transform = function(value) {
            # Convert percentage loss to multiplier
            1 - (value / 100)
        },
        value_field = "non_adap_suppression_loss",
        create = function(start_time, end_time, value) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS$non_adap_suppression_loss$quantity_name,
                scale = MODEL_EFFECTS$non_adap_suppression_loss$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS$non_adap_suppression_loss$transform
            )
        }
    )
)
