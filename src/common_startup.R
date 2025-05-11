# src/common_startup.R
# Handles common library loading, sourcing of shared R scripts, and onStart logic.

# --- 1. Load Essential Libraries ---
print("[COMMON_STARTUP] Loading essential libraries...")
library(shiny)
library(shinyjs)
library(shinycssloaders)
library(cachem)
library(magrittr)
library(plotly)
library(httr2)
library(promises)
library(future)
library(jheem2)
print("[COMMON_STARTUP] Essential libraries loaded.")

# --- 2. Source Common R Scripts ---
# This section will replicate the sourcing from the top of app.R for shared utilities.
# We need to be careful with paths, assuming this script is in src/ and app_*.R are in root.
# Paths in sourced scripts might need to be relative to the project root or adjusted.

print("[COMMON_STARTUP] Sourcing common R scripts...")

# Configuration system
source("src/ui/config/load_config.R") # Already sourced directly in app_prerun/custom for now

# Common UI components and helpers
source("src/ui/components/common/popover/popover.R") # Example

# State management system
source("src/ui/state/types.R")
source("src/ui/state/store.R")
source("src/ui/state/visualization.R")
source("src/ui/state/controls.R")
source("src/ui/state/validation.R")

# State synchronization system
source("src/ui/components/common/display/state_sync.R")

# Data layer components
source("src/data/cache.R") # Old cache, might be superseded by unified_cache
source("src/data/unified_cache/helpers.R")
source("src/adapters/simulation_adapter.R")
source("src/adapters/intervention_adapter.R")

# Common Display components (subset of what app.R sources, more might be needed)
source("src/ui/components/common/display/plot_panel.R") # If used directly by layouts
source("src/ui/components/common/display/table_panel.R") # If used directly by layouts

# Error handling
source("src/ui/components/common/errors/boundaries.R")
source("src/ui/components/common/errors/handlers.R")
source("src/ui/components/common/layout/panel.R") # If common panel structures are used

# Selectors (if base or custom_components are used broadly)
source("src/ui/components/selectors/base.R")
source("src/ui/components/selectors/custom_components.R")
source("src/ui/components/selectors/choices_select.R")

# Model status
source("src/ui/components/common/status/model_status.R")

# Download manager (the script, not the instance creation)
source("src/ui/components/common/downloads/download_manager.R")

# Progress tracking (the script, not the instance creation)
source("src/ui/components/common/progress/init.R")

# Other common utilities from app.R's global scope
source("src/ui/components/common/display/display_size.R") # For display size handling
source("src/ui/components/common/display/handlers.R") # For common display handlers
source("src/ui/messaging/ui_messenger.R") # For UI messenger capabilities

# Note: Page-specific layouts (prerun/custom) and their specific index.R files
# will be sourced directly by app_prerun.R and app_custom.R respectively.
# Static page components (About, Contact, Team) are not included here as they
# are not part of the core prerun/custom apps, though contact might be added later if needed.

print("[COMMON_STARTUP] Common R scripts sourced.")


# --- 3. onStart Logic ---
# This replicates the onStart behavior from the main app.R
common_onStart_logic <- function() {
    print("[COMMON_STARTUP] Executing onStart logic: Loading jheem2 internal functions to .GlobalEnv")
    pkg_env <- asNamespace("jheem2")
    internal_fns <- ls(pkg_env, all.names = TRUE)

    for (fn in internal_fns) {
        if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
            assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
        }
    }
    print("[COMMON_STARTUP] jheem2 internal functions loaded.")
}

# Optional: A function to be called by shinyApp(onStart = ...)
get_common_onStart_function <- function() {
    return(common_onStart_logic)
}

print("[COMMON_STARTUP] Script loaded. common_onStart_logic() and get_common_onStart_function() are defined.")
