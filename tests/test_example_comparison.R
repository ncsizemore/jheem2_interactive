# Test with the exact example provided

# Source the functions we need
source("src/ui/state/compare_components.R")

# Create components exactly as they were in the example
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
            value = 0  # This differs from comp2
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
            value = 3  # Different value here
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

# Print the components for verification
cat("Component 1:\n")
str(comp1)
cat("\nComponent 2:\n")
str(comp2)
cat("\n")

# Test the comparison
cat("============== COMPARISON TEST ==============\n")
cat("Testing comparison with values 0 vs 3 - should be FALSE\n")
result <- compare_components(comp1, comp2)
cat("Comparison result:", result, "\n")
cat("===========================================\n\n")

# Try with identical components as a control
cat("============== CONTROL TEST ==============\n")
cat("Testing comparison with identical components - should be TRUE\n")
result2 <- compare_components(comp1, comp1)
cat("Comparison result:", result2, "\n")
cat("===========================================\n")
