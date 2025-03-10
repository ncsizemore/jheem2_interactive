#' TEMPORARY FIX for JHEEM2 package bug
#' Redirects calls to the misspelled function to the correct one
#' @param code Intervention code
#' @param throw.error.if.missing Whether to throw error if intervention not found
#' @return Intervention object or NULL if not found
get.intervention.from.code.from.code <- function(code, throw.error.if.missing = TRUE) {
# WORKAROUND: This function is misspelled in the JHEEM2 package
# Redirect to the correct function
get.intervention.from.code(code, throw.error.if.missing)
}

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
    # Handle transform if provided
effect_value <- if (!is.null(transform)) {
    transform(value)
} else {
    # For suppression_loss, convert percentage to proportion and apply formula
if (group_id %in% c("adap", "oahs", "other")) {
    # Calculate 1 - value/100 directly
1 - (value / 100)
} else {
    value
}
}

# Handle case where quantity_name is a function that requires group_id
actual_quantity_name <- if (is.function(quantity_name) && !is.null(group_id)) {
    quantity_name(group_id)
} else {
    quantity_name
}

# Convert to numeric
start_time_num <- suppressWarnings(as.numeric(start_time))

# Simplified approach: use a single time point instead of vectors
# This ensures proper foreground creation
create.intervention.effect(
quantity.name = actual_quantity_name,
    start.time = start_time_num,
effect.values = effect_value,
    apply.effects.as = "value",
    scale = scale,
    times = start_time_num + 0.25,  # Just use a single time point
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

#' Determine if an effect is temporary based on date settings
#' @param start_time Start year of the effect
#' @param end_time End year of the effect
#' @return TRUE if temporary, FALSE if permanent
is_temporary_effect <- function(start_time, end_time) {
    # Silence warnings for this function
    old <- options(warn = -1)
    on.exit(options(old))
    
    # Handle the "never" case explicitly
    if (is.null(end_time) || identical(end_time, "never")) {
        return(FALSE)
    }
    
    # Convert both values to numeric, with warning suppressed globally
    start_time_num <- as.numeric(start_time)
    end_time_num <- as.numeric(end_time)
    
    # If either value couldn't be converted, default to permanent
    if (is.na(start_time_num) || is.na(end_time_num)) {
        return(FALSE)
    }
    
    # If end_time is a numeric year and greater than start_time, it's temporary
    if (end_time_num > start_time_num) {
        return(TRUE)
    }
    
    # Default to permanent
    return(FALSE)
}

#' Model effect configurations
MODEL_EFFECTS <- list(
    # Generic suppression_loss effect that works for any group
    suppression_loss = list(
        quantity_name = function(group_id) {
            if (group_id == "adap") {
                "adap.suppression.effect"
            } else if (group_id == "oahs") {
                "oahs.suppression.effect" 
            } else if (group_id == "other") {
                "rw.support.suppression.effect"
            } else {
                stop(paste("Unknown group ID for suppression_loss:", group_id))
            }
        },
        scale = "proportion",
        value_field = "value",
        create = function(start_time, end_time, value, group_id) {
            # Check if this is a temporary or permanent effect based on dates
            is_temp <- is_temporary_effect(start_time, end_time)
            
            create_standard_effect(
                quantity_name = MODEL_EFFECTS[["suppression_loss"]]$quantity_name,
                scale = MODEL_EFFECTS[["suppression_loss"]]$scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                is_temporary = is_temp,
                group_id = group_id
            )
        }
    )
)
