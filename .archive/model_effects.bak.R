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
    # DEBUG: Start of create_standard_effect
print("=== DEBUG: create_standard_effect - FULL DIAGNOSTIC ====")
trace.calls <- lapply(sys.calls(), deparse)
print("Function call stack:")
for (i in length(trace.calls):1) {
    print(paste(i, trace.calls[[i]]))
}
    print(paste0("Input quantity_name: '", quantity_name, "'"))
    print(paste0("Input quantity_name type: ", typeof(quantity_name)))
    print(paste0("scale: '", scale, "'"))
    print(paste0("start_time: ", start_time))
    print(paste0("end_time: ", end_time))
    print(paste0("value: ", value))
    print(paste0("group_id: ", group_id))
    
    # Validate quantity_name
    if (is.null(quantity_name) || !is.character(quantity_name) || length(quantity_name) != 1 || nchar(quantity_name) == 0) {
        print("ERROR: quantity_name must be a single, non-empty character string")
        stop("Cannot create effect: quantity_name must be a single, non-empty character string")
    }
    
    # Validate scale
    if (is.null(scale) || !is.character(scale) || length(scale) != 1 || nchar(scale) == 0) {
        print("WARNING: Using default scale 'proportion' because scale was invalid")
        scale <- "proportion"
    }
    
    # DEBUG: Handle transform
    print("--- Processing effect value ---")
    
    # Handle transform if provided
    effect_value <- if (!is.null(transform) && is.function(transform)) {
        transform(value)
    } else {
        # For suppression_loss, convert percentage to proportion and apply formula
        if (group_id %in% c("adap", "oahs", "other")) {
            # Match pattern from Ryan White interventions: 1-lose.effect (1 minus the effect)
            result <- 1 - (value / 100)
            print(paste0("Calculated effect_value for group ", group_id, ": ", result))
            result
        } else {
            print(paste0("Using raw value: ", value))
            value
        }
    }
    
    # DEBUG: Handle quantity_name resolution
    print("--- Processing quantity_name ---")
    
    # Handle case where quantity_name is a function that requires group_id
    # This shouldn't happen anymore due to our earlier validation, but keeping simpler logic just in case
    if (is.function(quantity_name) && !is.null(group_id)) {
        # Try to call the function with group_id
        actual_quantity_name <- tryCatch({
            result <- quantity_name(group_id)
            print(paste0("Function evaluated to: '", result, "'"))
            if (!is.character(result) || length(result) != 1 || nchar(result) == 0) {
                stop("Function must return a single, non-empty character string")
            }
            result
        }, error = function(e) {
            print(paste0("ERROR: Function evaluation failed: ", e$message))
            stop(paste0("Cannot resolve quantity_name function: ", e$message))
        })
    } else {
        actual_quantity_name <- quantity_name
    }
    
    print(paste0("Final quantity_name: '", actual_quantity_name, "'"))
    
    # Convert to numeric
    start_time_num <- suppressWarnings(as.numeric(start_time))
    print(paste0("Converted start_time to numeric: ", start_time_num))
    
    # DEBUG: Creating intervention effect
    print("--- Creating intervention effect ---")
    print(paste0("quantity.name: '", actual_quantity_name, "'"))
    print(paste0("start.time: ", start_time_num))
    print(paste0("effect.values: ", effect_value))
    print(paste0("scale: ", scale))
    print(paste0("times: ", start_time_num + 0.25))
    
    # Simplified approach: use a single time point instead of vectors
    # This ensures proper foreground creation
    effect <- tryCatch({
        # Ensure end_time is properly handled for 'never' or NULL cases
        end_time_num <- if (!is.null(end_time) && !identical(end_time, "never")) {
            suppressWarnings(as.numeric(end_time))
        } else {
            # If 'never' or NULL, use START.YEAR + 0.3 to match Ryan White pattern
            # The Ryan White code uses START.YEAR and IMPLEMENTED.BY.YEAR (which is START.YEAR + 0.3)
            start_time_num + 0.3
        }
        
        # Ensure end_time is valid
        if (is.na(end_time_num) || end_time_num <= start_time_num) {
            end_time_num <- start_time_num + 0.3  # Use same offset as the Ryan White pattern
        }
        
        print(paste0("Using start_time: ", start_time_num, ", end_time: ", end_time_num))
        
        created_effect <- create.intervention.effect(
            quantity.name = actual_quantity_name,
            start.time = start_time_num,
            effect.values = effect_value,
            apply.effects.as = "value",
            scale = scale,
            times = end_time_num,  # Match Ryan White pattern using end_time
            allow.values.less.than.otherwise = T,
            allow.values.greater.than.otherwise = F  # Exact Ryan White pattern
        )
        
        print("--- Detailed effect inspection ---")
        print(paste0("Effect S3 class: ", paste(class(created_effect), collapse=", ")))
        print(paste0("Effect is R6: ", R6::is.R6(created_effect)))
        if (R6::is.R6(created_effect)) {
            print("Effect public methods/fields:")
            print(names(created_effect))
            print(paste0("Effect quantity.name: ", created_effect$quantity.name))
            print(paste0("Effect start.time: ", created_effect$start.time))
            print(paste0("Effect times: ", paste(created_effect$times, collapse=", ")))
            print(paste0("Effect is.resolved: ", created_effect$is.resolved))
            print(paste0("Effect all.times: ", paste(created_effect$all.times, collapse=", ")))
        }
        
        # DEBUG: Check created effect
        print("--- Effect creation result ---")
        print(paste0("Effect class: ", paste(class(created_effect), collapse=", ")))
        print(paste0("Effect is NULL: ", is.null(created_effect)))
        if (!is.null(created_effect)) {
            print(paste0("Effect quantity.name: ", created_effect$quantity.name))
            print(paste0("Effect is resolved: ", created_effect$is.resolved))
        }
        
        created_effect
    }, error = function(e) {
        print(paste0("ERROR creating effect: ", e$message))
        NULL
    })
    
    print("=== END create_standard_effect ====")
    effect
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
            print(paste0("DEBUG: quantity_name function called with group_id: '", group_id, "'"))
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
            print("=== DEBUG: suppression_loss create function ====")
            print(paste0("group_id: '", group_id, "'"))
            print(paste0("start_time: ", start_time))
            print(paste0("end_time: ", end_time))
            print(paste0("value: ", value))
            
            # Check if this is a temporary or permanent effect based on dates
            is_temp <- is_temporary_effect(start_time, end_time)
            print(paste0("is_temporary: ", is_temp))
            
            # DEBUG: Model effects access
            print("DEBUG: MODEL_EFFECTS keys:")
            print(names(MODEL_EFFECTS))
            
            # Fix the access to MODEL_EFFECTS - use direct variable access instead of []
            # This ensures we get the actual function reference rather than potentially NULL
            quantity_name_fn <- MODEL_EFFECTS$suppression_loss$quantity_name
            print(paste0("quantity_name_fn type: ", typeof(quantity_name_fn)))
            print(paste0("is.function(quantity_name_fn): ", is.function(quantity_name_fn)))
            
            # Extract quantity_name directly instead of by reference
            local_quantity_name <- NULL
            if (is.function(quantity_name_fn)) {
                try({
                    local_quantity_name <- quantity_name_fn(group_id)
                    print(paste0("Function evaluated to: '", local_quantity_name, "'"))
                }, silent = FALSE)
            }
            
            # Get scale directly rather than by reference
            local_scale <- MODEL_EFFECTS$suppression_loss$scale
            
            # Use direct values that we know are correct rather than references
            create_standard_effect(
                quantity_name = local_quantity_name,
                scale = local_scale,
                start_time = start_time,
                end_time = end_time,
                value = value,
                group_id = group_id
            )
        }
    )
)