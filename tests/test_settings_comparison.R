# Test script for settings comparison

# Source the updated functions
source("src/ui/state/store_comparison.R")

# Run the test
test_settings_comparison()

# Print a message to make it clear this is a test script
cat("\n\n")
cat("==============================================================\n")
cat("This is a test of the settings comparison function.\n")
cat("The test creates two settings with different component values (0 vs 3),\n")
cat("so the result should be FALSE (not matching).\n")
cat("==============================================================\n")
