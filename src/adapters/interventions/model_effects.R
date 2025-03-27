# Model-specific configuration
MODEL_CONFIG <- list(
  # Whether this model uses WHOLE.POPULATION for all interventions
  use_whole_population = TRUE,
  
  # Whether this model supports targeting demographic subgroups
  supports_subgroup_targeting = FALSE
)

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

#' Check if model uses whole population approach
#' @return TRUE if model uses WHOLE.POPULATION for all interventions
uses_whole_population <- function() {
  MODEL_CONFIG$use_whole_population
}

#' Check if model supports targeting subgroups
#' @return TRUE if model supports demographic subgroup targeting
supports_subgroup_targeting <- function() {
  MODEL_CONFIG$supports_subgroup_targeting
}

#' Create a standard intervention effect
#' @param quantity_name Name of the quantity to affect or function to dynamically determine quantity
#' @param scale Type of scale (proportion or rate)
#' @param start_time Start year
#' @param end_time End year or NULL/NA/"never" for permanent effect
#' @param value Effect value
#' @param transform Function to transform value (optional)
#' @param group_id Group identifier for dynamic quantity determination (optional)
#' @param recovery_duration Recovery duration in months (optional, default 3 months)
#' @return jheem intervention effect
create_standard_effect <- function(quantity_name, scale, start_time, end_time, value, transform = NULL, group_id = NULL, recovery_duration = NULL) {
  # Handle dynamic quantity names based on group_id
  if (is.function(quantity_name)) {
    quantity_name <- quantity_name(group_id)
  }
  
  # Apply transformation if provided
  effect_value <- if (!is.null(transform) && is.function(transform)) {
    transform(value)
  } else if (group_id %in% c("adap", "oahs", "other")) {
    # Special case for Ryan White suppression loss
    1 - (value / 100)
  } else {
    value
  }
  
  # Convert to numeric
  start_time_num <- suppressWarnings(as.numeric(start_time))
  
  # Check if this is a temporary or permanent effect
  is_temporary <- !is.null(end_time) && 
                  !is.na(end_time) && 
                  end_time != "" && 
                  end_time != "never"
  
  # Print debug info
  print(paste("Creating", ifelse(is_temporary, "TEMPORARY", "PERMANENT"), "effect:"))
  print(paste("  Quantity:", quantity_name))
  print(paste("  Start time:", start_time_num))
  print(paste("  End time:", ifelse(is_temporary, as.numeric(end_time), "N/A")))
  print(paste("  Effect value:", effect_value))
  
  # Create appropriate effect based on type
  if (is_temporary) {
    # For temporary effects, use the Ryan White pattern with start/end times
    end_time_num <- suppressWarnings(as.numeric(end_time))
    
    # Calculate recovery period in years (default to 3 months if not specified)
    recovery_years <- if (!is.null(recovery_duration)) {
      recovery_months <- as.numeric(recovery_duration)
      print(paste("  Using recovery duration of", recovery_months, "months"))
      recovery_months / 12  # Convert months to years
    } else {
      print("  Using default recovery duration of 3 months")
      0.25  # Default 3 months (1/4 year)
    }
    
    print(paste("  Creating temporary effect ending at", end_time_num, "with recovery duration of", recovery_years, "years"))
    
    # Create effect with array of values and times
    create.intervention.effect(
      quantity.name = quantity_name,
      start.time = start_time_num,
      end.time = end_time_num + recovery_years,  # Add recovery duration
      effect.values = c(effect_value, effect_value),  # Same value at both time points
      apply.effects.as = "value",
      scale = scale,
      times = c(start_time_num + 0.3, end_time_num),  # Implementation time and return start time
      allow.values.less.than.otherwise = TRUE,
      allow.values.greater.than.otherwise = FALSE
    )
  } else {
    # For permanent effects, use the simpler pattern
    print("  Creating permanent effect (never returns)")
    
    create.intervention.effect(
      quantity.name = quantity_name,
      start.time = start_time_num,
      effect.values = effect_value,
      apply.effects.as = "value",
      scale = scale,
      times = start_time_num + 0.3,  # Ryan White uses +0.3 from start time
      allow.values.less.than.otherwise = TRUE,  # RW specific
      allow.values.greater.than.otherwise = FALSE  # RW specific
    )
  }
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
    create = function(start_time, end_time, value, group_id, recovery_duration = NULL) {
      create_standard_effect(
        quantity_name = MODEL_EFFECTS$suppression_loss$quantity_name,
        scale = MODEL_EFFECTS$suppression_loss$scale,
        start_time = start_time,
        end_time = end_time,
        value = value,
        group_id = group_id,
        recovery_duration = recovery_duration
      )
    }
  )
)
