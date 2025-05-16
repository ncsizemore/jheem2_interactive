# Deploy to shinyapps.io with specific files
remove.packages("jheem2")
remotes::install_github("tfojo1/jheem2@dev")
remotes::install_github("tfojo1/jheem2@test_deploy")
options(rsconnect.max.bundle.size = 5e9)
options(timeout = 600)
httr::set_config(httr::timeout(600))
rsconnect::deployApp(
  appDir = "/Users/nicholas/Documents/jheem/code/jheem2_interactive",
  appName = "ryan-white",
  account = "jheem",
  appFiles = c(
    "app.R",
    ".Renviron",
    "deployment/deployment_dependencies.R",
    list.files("src", recursive = TRUE, full.names = TRUE),
    list.files("www", recursive = TRUE, full.names = TRUE),
    list.files("external/jheem_analyses", recursive = TRUE, full.names = TRUE),
    list.files("simulations/ryan-white", recursive = TRUE, full.names = TRUE)
  ),
  forceUpdate = TRUE,
  lint = FALSE
)

rsconnect::writeManifest(
  appFiles = c(
    # Core app files
    "app.R",
    # Other files
    list.files("src", recursive = TRUE, full.names = TRUE),
    list.files("www", recursive = TRUE, full.names = TRUE)
  )
)

library(jheem2)


options(rsconnect.max.bundle.size = 5e9)
options(timeout = 600)
httr::set_config(httr::timeout(600))
rsconnect::deployApp(
  appDir = "/Users/nicholas/Documents/jheem/code/jheem2_interactive",
  appName = "ryan-white-prerun", # Changed appName
  appMode = "shiny",
  appPrimaryDoc = "app_prerun.R",
  account = "jheem",
  appFiles = c(
    "app_prerun.R", # Changed app file
    ".Renviron",
    "deployment/deployment_dependencies.R",
    list.files("src", recursive = TRUE, full.names = TRUE),
    list.files("www", recursive = TRUE, full.names = TRUE),
    list.files("external/jheem_analyses", recursive = TRUE, full.names = TRUE),
    list.files("simulations/ryan-white", recursive = TRUE, full.names = TRUE)
  ),
  forceUpdate = TRUE,
  lint = FALSE
)

options(rsconnect.max.bundle.size = 5e9)
options(timeout = 600)
httr::set_config(httr::timeout(600))
rsconnect::deployApp(
  appDir = "/Users/nicholas/Documents/jheem/code/jheem2_interactive",
  appName = "ryan-white-custom", # Changed appName
  appMode = "shiny",
  appPrimaryDoc = "app_custom.R",
  account = "jheem",
  appFiles = c(
    "app_custom.R", # Changed app file
    ".Renviron",
    "deployment/deployment_dependencies.R",
    list.files("src", recursive = TRUE, full.names = TRUE),
    list.files("www", recursive = TRUE, full.names = TRUE),
    list.files("external/jheem_analyses", recursive = TRUE, full.names = TRUE),
    list.files("simulations/ryan-white", recursive = TRUE, full.names = TRUE)
  ),
  forceUpdate = TRUE,
  lint = FALSE
)
