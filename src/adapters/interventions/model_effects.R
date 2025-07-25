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
#' @param suffix Optional suffix to add to quantity name (e.g., "expansion" or "nonexpansion")
#' @return jheem intervention effect
create_standard_effect <- function(quantity_name, scale, start_time, end_time, value, transform = NULL, group_id = NULL, recovery_duration = NULL, suffix = NULL) {
  # Handle dynamic quantity names based on group_id
  if (is.function(quantity_name)) {
    quantity_name <- quantity_name(group_id, suffix)
  }

  # Add suffix if provided
  if (!is.null(suffix) && !grepl(paste0("\\.", suffix, "\\."), quantity_name)) {
    # Only add suffix if it's not already part of the quantity name
    quantity_name <- gsub("\\.$", paste0(".", suffix, "."), quantity_name)
    quantity_name <- gsub("\\.$", "", quantity_name) # Remove trailing dot if any
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
      recovery_months / 12 # Convert months to years
    } else {
      print("  Using default recovery duration of 3 months")
      0.25 # Default 3 months (1/4 year)
    }

    print(paste("  Creating temporary effect ending at", end_time_num, "with recovery duration of", recovery_years, "years"))

    # Create effect with array of values and times
    create.intervention.effect(
      quantity.name = quantity_name,
      start.time = start_time_num,
      end.time = end_time_num + recovery_years, # Add recovery duration
      effect.values = c(effect_value, effect_value), # Same value at both time points
      apply.effects.as = "value",
      scale = scale,
      times = c(start_time_num + 0.3, end_time_num), # Implementation time and return start time
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
      times = start_time_num + 0.3, # Ryan White uses +0.3 from start time
      allow.values.less.than.otherwise = TRUE, # RW specific
      allow.values.greater.than.otherwise = FALSE # RW specific
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

#' Model effect configurations for CDC Testing model
MODEL_EFFECTS <- list(
  # CDC testing reduction effect for whole population
  # Controls how much CDC-funded testing is reduced
  testing_reduction = list(
    quantity_name = function(group_id, suffix = NULL) {
      # CDC testing uses cdc.effect for the whole population
      "cdc.effect"
    },
    scale = "proportion",
    value_field = "value",
    create = function(start_time, end_time, value, group_id, recovery_duration = NULL) {
      # Convert percentage reduction to cdc.effect value
      # If 100% reduction -> cdc.effect = 0 (no CDC testing)
      # If 50% reduction -> cdc.effect = 0.5 (half CDC testing)
      # If 0% reduction -> cdc.effect = 1 (full CDC testing)
      cdc_effect_value <- 1 - (value / 100)

      print(paste("CDC Testing Effect: Converting", value, "% reduction to cdc.effect =", cdc_effect_value))

      # Create single CDC effect using the same pattern as working CDC interventions
      cdc_effect <- create.intervention.effect(
        quantity.name = "cdc.effect",
        start.time = start_time,
        effect.values = cdc_effect_value,
        times = start_time + 0.25, # Use CDC testing pattern
        scale = "proportion",
        apply.effects.as = "value",
        allow.values.less.than.otherwise = TRUE,
        allow.values.greater.than.otherwise = FALSE
      )

      # Return a list with single effect for consistency with intervention adapter
      list(cdc_effect)
    }
  ),

  # Proportion tested regardless of CDC funding
  # Controls what fraction continue testing without CDC programs
  proportion_tested_regardless = list(
    quantity_name = function(group_id, suffix = NULL) {
      # Maps to the proportion.tested.regardless parameter
      "proportion.tested.regardless"
    },
    scale = "proportion",
    value_field = "value",
    create = function(start_time, end_time, value, group_id, recovery_duration = NULL) {
      # Convert percentage to proportion
      # 50% -> 0.5, 25% -> 0.25, etc.
      proportion_value <- value / 100

      print(paste("Proportion Tested Regardless: Converting", value, "% to proportion =", proportion_value))

      # This effect should be active from the beginning of the simulation
      # Use simset's start year to avoid timing conflicts
      proportion_effect <- create.intervention.effect(
        quantity.name = "proportion.tested.regardless",
        start.time = 2015,  # Match simset's from.year
        effect.values = proportion_value,
        times = 2015.25,  # Slight offset from start time
        scale = "proportion",
        apply.effects.as = "value",
        allow.values.less.than.otherwise = TRUE,
        allow.values.greater.than.otherwise = TRUE
      )

      # Return a list with single effect for consistency with intervention adapter
      list(proportion_effect)
    }
  )

  # NOTE: suppression_loss effects removed - they are not applicable to the CDC testing model
  # The CDC testing model (cdct specification) does not define Ryan White-specific quantities like:
  # - adap.suppression.expansion.effect
  # - oahs.suppression.expansion.effect
  # - rw.support.suppression.expansion.effect
)
