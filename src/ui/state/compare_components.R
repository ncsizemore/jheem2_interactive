#' Recursively compare two components for equality
#' @param comp1 First component
#' @param comp2 Second component
#' @param depth Current recursion depth (used for debug output)
#' @return Logical: TRUE if components are equivalent
compare_components <- function(comp1, comp2, depth = 0) {
    indent <- paste(rep("  ", depth), collapse = "")
    debug_prefix <- paste0(indent, "[compare_components][depth=", depth, "] ")
    
    # Debug output to trace the structure being compared
    if (depth == 0) {
        print("=============================================")
        print("Starting component comparison")
        print("=============================================")
    }
    
    # Base cases
    if (identical(comp1, comp2)) {
        print(paste0(debug_prefix, "Identical components - returning TRUE"))
        return(TRUE)
    }
    
    if (is.null(comp1) && is.null(comp2)) {
        print(paste0(debug_prefix, "Both NULL - returning TRUE"))
        return(TRUE) 
    }
    
    if (is.null(comp1) || is.null(comp2)) {
        print(paste0(debug_prefix, "One NULL, one not - returning FALSE"))
        return(FALSE)
    }
    
    # Print debug info about what we're comparing
    print(paste0(debug_prefix, "Comparing: ", 
                 typeof(comp1), " (length=", length(comp1), ") vs ",
                 typeof(comp2), " (length=", length(comp2), ")"))
    
    # Handle numeric values with tolerance
    if (is.numeric(comp1) && is.numeric(comp2)) {
        # Convert to vectors if needed
        comp1_vec <- as.vector(comp1)
        comp2_vec <- as.vector(comp2)
        
        # Check lengths
        if (length(comp1_vec) != length(comp2_vec)) {
            print(paste0(debug_prefix, "Numeric length mismatch: ", 
                         length(comp1_vec), " vs ", length(comp2_vec), 
                         " - returning FALSE"))
            return(FALSE)
        }
        
        # Use both absolute and relative tolerance for floating point
        abs_diff <- abs(comp1_vec - comp2_vec)
        abs_tolerance <- 1e-10
        rel_tolerance <- 1e-8 * pmax(abs(comp1_vec), abs(comp2_vec), 1e-10)
        all_match <- all(abs_diff < pmax(abs_tolerance, rel_tolerance))
        
        # For values that don't match, print them
        if (!all_match) {
            # Find which values don't match
            mismatch_indices <- which(abs_diff >= pmax(abs_tolerance, rel_tolerance))
            for (i in mismatch_indices) {
                print(paste0(debug_prefix, "Numeric mismatch at index ", i, ": ",
                             comp1_vec[i], " vs ", comp2_vec[i], 
                             " (diff=", abs_diff[i], ")"))
            }
        }
        
        print(paste0(debug_prefix, "Numeric comparison result: ", all_match))
        return(all_match)
    }
    
    # If types don't match, they're not equal
    if (typeof(comp1) != typeof(comp2)) {
        print(paste0(debug_prefix, "Type mismatch: ", typeof(comp1), " vs ", typeof(comp2), 
                     " - returning FALSE"))
        return(FALSE)
    }
    
    # For character values
    if (is.character(comp1) && is.character(comp2)) {
        # Check length and values
        if (length(comp1) != length(comp2)) {
            print(paste0(debug_prefix, "Character length mismatch: ", 
                         length(comp1), " vs ", length(comp2), 
                         " - returning FALSE"))
            return(FALSE)
        }
        
        # Compare values
        all_match <- all(comp1 == comp2)
        if (!all_match) {
            # Find which values don't match
            mismatch_indices <- which(comp1 != comp2)
            for (i in mismatch_indices) {
                print(paste0(debug_prefix, "Character mismatch at index ", i, ": ",
                             comp1[i], " vs ", comp2[i]))
            }
        }
        
        print(paste0(debug_prefix, "Character comparison result: ", all_match))
        return(all_match)
    }
    
    # For lists (most component structures)
    if (is.list(comp1) && is.list(comp2)) {
        # Special case for disabled components
        if (!is.null(comp1$enabled) && !is.null(comp2$enabled)) {
            # If both disabled, consider equal
            if (!comp1$enabled && !comp2$enabled) {
                print(paste0(debug_prefix, "Both components disabled - returning TRUE"))
                return(TRUE)
            }
            # If one enabled and other disabled, not equal
            if (comp1$enabled != comp2$enabled) {
                print(paste0(debug_prefix, "One enabled, one disabled - returning FALSE"))
                return(FALSE)
            }
            # Otherwise continue with normal comparison
        }
        
        # Critical special case for the components structure in the example
        # This handles the list(list(list(...))) structure we saw
        if (is.null(names(comp1)) && is.null(names(comp2))) {
            # If lengths don't match, they're not equal
            if (length(comp1) != length(comp2)) {
                print(paste0(debug_prefix, "Unnamed list length mismatch: ", 
                             length(comp1), " vs ", length(comp2),
                             " - returning FALSE"))
                return(FALSE)
            }
            
            print(paste0(debug_prefix, "Comparing unnamed lists item by item (length=", length(comp1), ")"))
            
            # Compare each element
            for (i in seq_along(comp1)) {
                print(paste0(debug_prefix, "Comparing unnamed list item ", i))
                if (!compare_components(comp1[[i]], comp2[[i]], depth + 1)) {
                    print(paste0(debug_prefix, "Unnamed list item ", i, " doesn't match - returning FALSE"))
                    return(FALSE)
                }
            }
            
            print(paste0(debug_prefix, "All unnamed list items match - returning TRUE"))
            return(TRUE)
        }
        
        # For named lists, compare each named item
        if (!is.null(names(comp1)) || !is.null(names(comp2))) {
            # Get all keys
            keys1 <- names(comp1)
            keys2 <- names(comp2)
            
            # If one has names and the other doesn't, they're not equal
            if (is.null(keys1) && !is.null(keys2)) {
                print(paste0(debug_prefix, "First has no keys, second has keys - returning FALSE"))
                return(FALSE)
            }
            if (!is.null(keys1) && is.null(keys2)) {
                print(paste0(debug_prefix, "First has keys, second has no keys - returning FALSE"))
                return(FALSE)
            }
            
            all_keys <- unique(c(keys1, keys2))
            print(paste0(debug_prefix, "Comparing named lists with keys: ", 
                         paste(all_keys, collapse=", ")))
            
            # Check each key
            for (key in all_keys) {
                # Skip comparison for certain keys that don't affect equality
                if (key %in% c("id", "timestamp", "created_at")) {
                    print(paste0(debug_prefix, "Skipping metadata key: ", key))
                    next
                }
                
                # Handle case of key in one but not the other
                if (!key %in% keys1) {
                    print(paste0(debug_prefix, "Key ", key, " missing from first - returning FALSE"))
                    return(FALSE)
                }
                if (!key %in% keys2) {
                    print(paste0(debug_prefix, "Key ", key, " missing from second - returning FALSE"))
                    return(FALSE)
                }
                
                # Print what we're comparing
                print(paste0(debug_prefix, "Comparing key: ", key))
                
                # Recursively compare values
                if (!compare_components(comp1[[key]], comp2[[key]], depth + 1)) {
                    print(paste0(debug_prefix, "Key ", key, " values don't match - returning FALSE"))
                    return(FALSE)
                }
            }
            
            print(paste0(debug_prefix, "All named keys match - returning TRUE"))
            return(TRUE)
        }
    }
    
    # For other types, use standard comparison
    result <- identical(comp1, comp2)
    print(paste0(debug_prefix, "Default comparison for type ", typeof(comp1), " - result: ", result))
    return(result)
}

#' Test function to compare the example components
#' @param print Print the components before comparing
#' @return Logical: TRUE if components match, FALSE otherwise
test_component_comparison <- function(print = TRUE) {
    # Create test components as seen in the example
    comp1 <- list(
        list(
            list(
                group = "adap",
                type = "suppression_loss",
                value = 70
            )
        ),
        list(
            list(
                group = "oahs",
                type = "suppression_loss",
                value = 0
            )
        ),
        list(
            list(
                group = "other",
                type = "suppression_loss",
                value = 0
            )
        )
    )
    
    comp2 <- list(
        list(
            list(
                group = "adap",
                type = "suppression_loss",
                value = 70
            )
        ),
        list(
            list(
                group = "oahs",
                type = "suppression_loss",
                value = 3  # Different value
            )
        ),
        list(
            list(
                group = "other",
                type = "suppression_loss",
                value = 0
            )
        )
    )
    
    if (print) {
        cat("Component 1:\n")
        str(comp1)
        cat("\nComponent 2:\n")
        str(comp2)
        cat("\n")
    }
    
    # Test the comparison function
    print("Running comparison test...")
    result <- compare_components(comp1, comp2)
    print(paste("Test result:", result))
    
    return(result)
}
