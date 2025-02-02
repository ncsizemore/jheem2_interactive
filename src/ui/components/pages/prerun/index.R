# src/ui/components/pages/prerun/index.R

# Load handlers in dependency order
source("src/ui/components/pages/prerun/handlers/visualization.R")
source("src/ui/components/pages/prerun/handlers/interventions.R")
source("src/ui/components/pages/prerun/handlers/initialize.R")

# Export the main initialization function
initialize_prerun_handlers
