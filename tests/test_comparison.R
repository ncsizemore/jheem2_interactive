# Test script for component comparison

# Source the comparison function
source("src/ui/state/compare_components.R")

# Run the test
test_component_comparison()

# Print a message to make it clear this is a test script
cat("\n\n")
cat("==============================================================\n")
cat("This is a test of the component comparison function.\n")
cat("The test creates two components with different values (0 vs 3),\n")
cat("so the result should be FALSE (not matching).\n")
cat("==============================================================\n")
