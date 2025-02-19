#' Model-specific intervention effect configurations
#' @description Defines how UI intervention settings map to model effects

#' Create a standard intervention effect
#' @param quantity_name Name of the quantity to affect (can be a function)
#' @param scale Type of scale (proportion or rate)
#' @param start_time Start year
#' @param end_time End year
#' @param value Effect value
#' @param transform Function to transform value (optional)
#' @param group_id Group identifier (optional)
#' @return jheem intervention effect
create_standard_effect <- function(quantity_name, scale, start_time, end_time, value, transform = NULL, group_id = NULL) {
    effect_value <- if (!is.null(transform)) transform(value) else value
    
    # Handle case where quantity_name is a function that requires group_id
    actual_quantity_name <- if (is.function(quantity_name) && !is.null(group_id)) {
        quantity_name(group_id)
    } else {
        quantity_name
    }
    
    print(paste("Creating effect for quantity:", actual_quantity_name, "with value:", effect_value))

    create.intervention.effect(
        quantity.name = actual_quantity_name,
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
#' @param group_id Optional group identifier for group-specific effects
#' @return List of effect configuration parameters
get_effect_config <- function(intervention_type, group_id = NULL) {
    # Try group-specific mapping first
    if (!is.null(group_id)) {
        group_specific_type <- paste0(group_id, "_", intervention_type)
        if (group_specific_type %in% names(MODEL_EFFECTS)) {
            return(MODEL_EFFECTS[[group_specific_type]])
        }
    }
    
    # Try generic type next
    if (intervention_type %in% names(MODEL_EFFECTS)) {
        return(MODEL_EFFECTS[[intervention_type]])
    }
    
    # Not found
    stop(sprintf("Unknown intervention type: %s (for group: %s)", 
               intervention_type, 
               if(is.null(group_id)) "any" else group_id))
}

#' Model effect configurations
MODEL_EFFECTS <- list(
    # Generic suppression_loss effect that works for any group
    suppression_loss = list(
        quantity_name = function(group_id) {
            if (group_id == "adap") {
                "adap.suppression.effect"
            } else if (group_id == "non_adap") {
                "rw.without.adap.suppression.effect"
            } else {
                stop(paste("Unknown group ID for suppression_loss:", group_id))
            }
        },
        scale = "proportion",
        transform = function(value) {
            # Convert percentage loss to multiplier
            # e.g., 25% loss becomes 0.75 multiplier
            1 - (value / 100)
        },
        value_field = "value",
        create = function(start_time, end_time, value, group_id) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS[["suppression_loss"]]$quantity_name,
                scale = MODEL_EFFECTS[["suppression_loss"]]$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS[["suppression_loss"]]$transform,
                group_id = group_id
            )
        }
    ),
    
    # Keep the specific effects for backward compatibility
    adap_suppression_loss = list(
        quantity_name = "adap.suppression.effect",
        scale = "proportion",
        transform = function(value) {
            # Convert percentage loss to multiplier
            1 - (value / 100)
        },
        value_field = "adap_suppression_loss",
        create = function(start_time, end_time, value, group_id = NULL) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS[["adap_suppression_loss"]]$quantity_name,
                scale = MODEL_EFFECTS[["adap_suppression_loss"]]$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS[["adap_suppression_loss"]]$transform
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
        create = function(start_time, end_time, value, group_id = NULL) {
            create_standard_effect(
                quantity_name = MODEL_EFFECTS[["non_adap_suppression_loss"]]$quantity_name,
                scale = MODEL_EFFECTS[["non_adap_suppression_loss"]]$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                transform = MODEL_EFFECTS[["non_adap_suppression_loss"]]$transform
            )
        }
    )
)
