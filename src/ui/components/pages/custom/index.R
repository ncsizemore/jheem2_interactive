# src/ui/components/pages/custom/index.R

# Load handlers in dependency order
source("src/ui/components/pages/custom/handlers/visualization.R")
source("src/ui/components/pages/custom/handlers/interventions.R")
source("src/ui/components/pages/custom/handlers/initialize.R")

# Export the main initialization function
initialize_custom_handlers
