# Diagnostic version of app.R
# Add at the very beginning of app.R

# Create a log function that writes to a file
debug_log <- function(message) {
  log_file <- file.path("debug_log.txt")
  cat(paste0(Sys.time(), ": ", message, "\n"), 
      file = log_file, 
      append = TRUE)
  # Also print to console for local testing
  message(message)
}

# Start fresh log
if (file.exists("debug_log.txt")) file.remove("debug_log.txt")
debug_log("Starting application initialization")

# Load essential libraries with error checking
load_package <- function(pkg) {
  debug_log(paste("Attempting to load package:", pkg))
  result <- tryCatch({
    library(pkg, character.only = TRUE)
    debug_log(paste("Successfully loaded package:", pkg))
    TRUE
  }, error = function(e) {
    debug_log(paste("ERROR loading package:", pkg, "-", e$message))
    FALSE
  })
  return(result)
}

# Try loading core packages
load_package("shiny")
load_package("shinyjs")
load_package("shinycssloaders")
load_package("cachem")
load_package("magrittr")

debug_log("Checking for vendor directories")
# Check if vendor directories exist
for (dir in c("vendor/jheem2/R", "vendor/jheem2/src", "vendor/jheem_analyses/applications/EHE")) {
  if (dir.exists(dir)) {
    debug_log(paste("Directory exists:", dir))
    debug_log(paste("Files in directory:", paste(list.files(dir), collapse=", ")))
  } else {
    debug_log(paste("ERROR: Directory missing:", dir))
  }
}

# Continue with initialization
debug_log("Attempting to source init-jheem2.R")
tryCatch({
  source("init-jheem2.R")
  debug_log("Successfully sourced init-jheem2.R")
}, error = function(e) {
  debug_log(paste("ERROR sourcing init-jheem2.R:", e$message))
})

# Now continue with regular app.R content
debug_log("Beginning to source UI components")
