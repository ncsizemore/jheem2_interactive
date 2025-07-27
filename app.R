# app.R


# Core UI packages
library(shiny)
library(shinyjs)
library(shinycssloaders)
library(cachem)
library(magrittr)
library(plotly)
library(httr2) # Required for API calls
library(promises) # For asynchronous operations
library(future) # For background processing

# Helper function to get a specific query parameter
getQueryParam <- function(queryString, paramName) {
  if (is.null(queryString) || queryString == "") {
    return(NULL)
  }
  # Remove leading '?'
  queryString <- sub("^\\?", "", queryString)
  params <- strsplit(queryString, "&")[[1]]
  for (p in params) {
    pair <- strsplit(p, "=")[[1]]
    if (length(pair) == 2 && URLdecode(pair[1]) == paramName) {
      return(URLdecode(pair[2]))
    }
  }
  return(NULL)
}

# Initialize remote logging if enabled
# source("src/utils/logging.R")
# initialize_logging()

# Source configuration system
source("src/ui/config/load_config.R")

# Load page configurations ONCE globally
print("Loading PRERUN page config globally...")
PRERUN_CONFIG <- get_page_complete_config("prerun")
print("Loading CUSTOM page config globally...")
CUSTOM_CONFIG <- get_page_complete_config("custom")
print("Global configs loaded.")

# Source components and helpers
source("src/ui/components/common/popover/popover.R")

# Source state management system
source("src/ui/state/types.R")
source("src/ui/state/store.R")
source("src/ui/state/visualization.R")
source("src/ui/state/controls.R")
source("src/ui/state/validation.R")

# Source state synchronization system
source("src/ui/components/common/display/state_sync.R")

# Source data layer components
source("src/data/cache.R")
source("src/data/unified_cache/helpers.R")
source("src/adapters/simulation_adapter.R")
source("src/adapters/intervention_adapter.R")

# Source display components
source("src/ui/components/common/display/plot_panel.R")
source("src/ui/components/common/display/table_panel.R")
source("src/ui/components/common/display/toggle.R")
source("src/ui/components/common/display/plot_controls.R")

# Source error handling
source("src/ui/components/common/errors/boundaries.R")
source("src/ui/components/common/errors/handlers.R")
source("src/ui/components/common/layout/panel.R")
source("src/ui/components/selectors/base.R")
source("src/ui/components/selectors/custom_components.R")
source("src/ui/components/selectors/choices_select.R")
source("src/ui/components/common/status/model_status.R")

# Source download manager
source("src/ui/components/common/downloads/download_manager.R")

# Source progress tracking
source("src/ui/components/common/progress/init.R")

source("src/ui/components/pages/prerun/layout.R")
source("src/ui/components/pages/custom/layout.R")


# Server handlers will be sourced inside the server function

# Source other required files
source("src/ui/components/common/display/display_size.R")
source("src/ui/components/common/display/handlers.R")

# Source page components
# Comment out unused pages for performance improvement
# source("src/ui/components/pages/about/about.R")
# source("src/ui/components/pages/about/content.R")
# source("src/ui/components/pages/faq/faq.R")
# source("src/ui/components/pages/faq/content.R")
# source("src/ui/components/pages/team/team.R")
# source("src/ui/components/pages/team/content.R")
# source("src/ui/components/pages/team/member_card.R")
# source("src/ui/components/pages/overview/overview.R")
# source("src/ui/components/pages/overview/content.R")

# Keep contact page which is still in use
source("src/ui/components/pages/contact/contact.R")
source("src/ui/components/pages/contact/content.R")
source("src/ui/components/pages/contact/form.R")

# Source download manager
source("src/ui/components/common/downloads/download_manager.R")

# Create a global download manager object that we'll initialize in server
DOWNLOAD_MANAGER <- NULL

library(jheem2)

# UI Creation
ui <- function() {
  # Load base configuration first
  base_config <- get_base_config()

  # Default selections from base config
  selected_tab <- base_config$application$defaults$selected_tab %||% "custom"
  app_title <- base_config$application$name

  # Configs are now loaded globally (PRERUN_CONFIG, CUSTOM_CONFIG)
  # Load contact page config specifically for the popover (still needed here)
  print("Loading contact page config (for popover)...")
  contact_config <- get_page_config("contact")

  tags$html(
    style = "height:100%",
    tags$title(app_title),

    # Initialize Shiny extensions
    shinyjs::useShinyjs(),

    # Load JavaScript extensions
    extendShinyjs(
      script = "js/layout/panel-controls.js",
      functions = c("ping_display_size", "ping_display_size_onload", "set_input_value")
    ),
    extendShinyjs(
      script = "js/interactions/download_plotly.js",
      functions = c("download_plotly")
    ),
    extendShinyjs(
      script = "js/interactions/sounds.js",
      functions = c("chime", "chime_if_checked")
    ),
    extendShinyjs(
      script = "js/interactions/download_progress.js",
      functions = c()
    ),

    # Load CSS files based on config
    tags$head(
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "css/main.css"
      ),

      # Explicitly load download progress CSS
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "css/components/feedback/download_progress.css"
      ),

      # Explicitly load simulation progress CSS
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "css/components/feedback/simulation_progress.css"
      ),

      # Load immediate loading CSS
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "css/components/feedback/immediate_loading.css"
      ),

      # Load simulation differences CSS
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "css/components/display/simulation_differences.css"
      ),

      # Load JavaScript files using base_config
      lapply(base_config$theme$scripts, function(script) {
        tags$script(src = script)
      }),
      # Load our state synchronization script
      tags$script(src = "js/state/visualization-sync.js"),
      # Load simulation progress script
      tags$script(src = "js/interactions/simulation_progress.js"),
      # Load progress positioning script
      tags$script(src = "js/interactions/progress_positioning.js"),
      # Load plot progress script
      tags$script(src = "js/interactions/plot_progress.js"),
      # REMOVED: Obsolete immediate loading script
      # tags$script(src = "js/interactions/immediate_loading.js"),
      # Load Plotly download helper script
      tags$script(src = "js/plotly_download.js"),
      tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/choices.js/public/assets/styles/choices.min.css"),
      tags$script(src = "https://cdn.jsdelivr.net/npm/choices.js/public/assets/scripts/choices.min.js"),
      tags$script("console.log('Dependencies loaded');"),
    ),
    tags$body(
      style = "height:100%;",
      # Add model status indicator
      create_model_status_ui(),
      # Download progress container is rendered by download_manager.R
      uiOutput("download_progress_container"),
      # Simulation progress container
      tags$div(id = "simulation-progress-container", class = "simulation-progress-container"),
      # Add hidden input for status tracking
      tags$input(type = "text", id = "model_status", style = "display:none;"),
      navbarPage(
        id = "main_nav",
        title = app_title,
        collapsible = FALSE,
        selected = selected_tab,

        # Overview tab - temporarily removed for performance
        # tabPanel(
        #   id = "overview",
        #   value = "overview",
        #   title = "Overview",
        #   make_tab_popover( # Use base_config
        #     "overview",
        #     title = base_config$pages$overview$popover$title,
        #     content = base_config$pages$overview$popover$content
        #   ),
        #   create_overview_page(base_config) # Use base_config
        # ),


        # Pre-run tab - Pass pre-loaded config
        tabPanel(
          title = "Pre-Run Scenarios",
          value = "prerun",
          # Use global config
          create_prerun_layout(config = PRERUN_CONFIG)
        ),

        # Custom tab - Pass pre-loaded config
        tabPanel(
          title = "Custom Simulations",
          value = "custom",
          # Use global config
          create_custom_layout(config = CUSTOM_CONFIG)
        ),

        # FAQ tab - temporarily removed for performance
        # tabPanel(
        #   title = "FAQ",
        #   value = "faq",
        #   make_tab_popover( # Use base_config
        #     "faq",
        #     title = base_config$pages$faq$popover$title,
        #     content = base_config$pages$faq$popover$content
        #   ),
        #   create_faq_page(base_config) # Use base_config
        # ),


        # About tab - temporarily removed for performance
        # tabPanel(
        #   title = "About the JHEEM",
        #   value = "about_the_jheem",
        #   make_tab_popover( # Use base_config
        #     "about_the_jheem",
        #     title = base_config$pages$about$popover$title,
        #     content = base_config$pages$about$popover$content
        #   ),
        #   create_about_page(base_config) # Use base_config
        # ),


        # Team tab - temporarily removed for performance
        # tabPanel(
        #   title = "Our Team",
        #   value = "our_team",
        #   make_tab_popover( # Use base_config
        #     "our_team",
        #     title = base_config$pages$team$popover$title,
        #     content = base_config$pages$team$popover$content
        #   ),
        #   create_team_page(base_config) # Use base_config
        # ),


        # Contact tab
        tabPanel(
          title = "Contact Us",
          value = "contact_us",
         # make_tab_popover( # Use contact_config for popover
          #  "contact_us",
          #  title = contact_config$popover$title,
          #  content = contact_config$popover$content
          #),
          # Pass the already loaded contact_config to the page creation function
          create_contact_page(contact_config)
        )
      )
    )
  )
}

# Server function
server <- function(input, output, session) {
  # Set up future plan for asynchronous operations
  # multisession works on all platforms; multicore is faster but Linux/macOS only (and not in RStudio)
  future::plan(multisession)
  print("[APP] Future plan set to multisession")

  # Observe the clientData$url_search once to set initial tab if specified
  observeEvent(session$clientData$url_search,
    {
      queryString <- session$clientData$url_search
      initial_tab_param <- getQueryParam(queryString, "initial_tab") # Using the helper

      # Ensure initial_tab_param is one of the valid tab values ("prerun" or "custom")
      # Add other valid tab values from your navbarPage if they exist
      valid_tabs <- c("prerun", "custom", "contact_us") # Added contact_us as an example, review your tabs

      if (!is.null(initial_tab_param) && initial_tab_param %in% valid_tabs) {
        print(paste0("[APP Server] URL parameter 'initial_tab' found: ", initial_tab_param, ". Switching tab."))
        updateNavbarPage(session, "main_nav", selected = initial_tab_param)
      } else if (!is.null(initial_tab_param)) {
        print(paste0("[APP Server] URL parameter 'initial_tab' has invalid value: ", initial_tab_param))
      }
    },
    once = TRUE
  ) # `once = TRUE` ensures this runs only one time when the session starts

  # Create error boundary for model loading
  model_boundary <- create_error_boundary(
    session,
    output,
    "global",
    "model_spec",
    state_manager = get_store()
  )

  # Create model status manager
  model_status <- create_model_status_manager(session, model_boundary)

  # Make the model status functions available to other components
  session$userData$load_model_spec <- model_status$load_model_spec
  session$userData$is_model_spec_loaded <- model_status$is_loaded

  # Backward compatibility for code that might still use the old function names
  # session$userData$load_ehe_spec <- model_status$load_model_spec
  # session$userData$is_ehe_spec_loaded <- model_status$is_loaded

  # Auto-load the model specification after UI is rendered
  session$onFlushed(function() {
    message("UI rendered, auto-loading model specification...")
    model_status$load_model_spec()
  })

  # Create reactive value at server level
  plot_state <- reactiveVal(
    lapply(c("prerun", "custom"), function(x) NULL) %>%
      setNames(c("prerun", "custom"))
  )

  # Initialize caches using the cache module
  cache_config <- get_component_config("caching")
  # Initialize unified cache manager
  print("[APP] Starting cache manager initialization")
  print(sprintf("[APP] Current working directory: %s", getwd()))

  # First, check important directories
  cache_dir <- "cache"
  onedrive_cache_dir <- "cache/onedrive"
  simulation_cache_dir <- "cache/simulations"

  print("[APP] Checking cache directories:")
  print(sprintf("[APP] Main cache directory exists: %s", dir.exists(cache_dir)))
  print(sprintf("[APP] OneDrive cache directory exists: %s", dir.exists(onedrive_cache_dir)))
  print(sprintf("[APP] Simulation cache directory exists: %s", dir.exists(simulation_cache_dir)))

  # Create cache directories if they don't exist
  if (!dir.exists(cache_dir)) {
    print("[APP] Creating main cache directory")
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(onedrive_cache_dir)) {
    print("[APP] Creating onedrive cache directory")
    dir.create(onedrive_cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(simulation_cache_dir)) {
    print("[APP] Creating simulation cache directory")
    dir.create(simulation_cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Now initialize the cache manager
  cache_manager <- tryCatch(
    {
      print("[APP] Calling get_cache_manager()")
      cm <- get_cache_manager()
      print("[APP] Cache manager initialization successful")
      print(sprintf("[APP] Cache manager class: %s", class(cm)[1]))
      cm
    },
    error = function(e) {
      print(sprintf("[APP] Error initializing cache manager: %s", e$message))
      print("[APP] Stack trace:")
      print(traceback())
      NULL
    }
  )

  # Check if initialization was successful
  if (!is.null(cache_manager)) {
    print("[APP] Cache manager initialized successfully")

    # Schedule periodic cleanup
    cleanup_interval <- cache_config$unified_cache$cleanup_interval_ms %||% 600000 # Default: 10 minutes
    print(sprintf("[APP] Scheduling cache cleanup every %d ms", cleanup_interval))
  } else {
    print("[APP] WARNING: Cache manager is NULL, caching will be degraded")
    print("[APP] Creating standard cache directories for fallback use")

    # Create standard cache directories that OneDriveProvider can use as fallback
    standard_cache_dirs <- c(
      "cache",
      "cache/onedrive",
      "cache/simulations"
    )

    for (dir_path in standard_cache_dirs) {
      if (!dir.exists(dir_path)) {
        print(sprintf("[APP] Creating standard cache directory: %s", dir_path))
        dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      }
    }

    print("[APP] Standard cache directories ready for use by providers")
  }

  # Initialize download progress container UI
  output$download_progress_container <- renderUI({
    tags$div(
      id = "download-progress-container",
      class = "download-progress-container"
    )
  })

  # Initialize download manager immediately instead of waiting for onFlushed
  # This ensures the reactive observers are established from the beginning
  DOWNLOAD_MANAGER <<- create_download_manager(session, output)
  print("[APP] Download manager initialized during server startup")

  # Initialize UI Messenger for direct messaging (bypassing reactive system)
  source("src/ui/messaging/ui_messenger.R")
  UI_MESSENGER <- create_ui_messenger(session)
  session$userData$ui_messenger <- UI_MESSENGER
  print("[APP] UI messenger initialized")

  # Initialize progress components
  progress_components <- init_progress_components(input, output, session)
  print("[APP] Progress components initialized")


  # Schedule periodic cleanup if cache manager was initialized
  if (!is.null(cache_manager)) {
    cleanup_interval <- cache_config$unified_cache$cleanup_interval_ms %||% 600000
    print(sprintf("[APP] Scheduling cache cleanup every %d ms", cleanup_interval))
  }

  # For backward compatibility, also initialize old caches
  initialize_caches(cache_config)

  # Initialize panel servers with reactive settings
  plot_panel_server(
    "prerun",
    settings = reactive({
      get_control_settings(input, "prerun")
    }),
    # Pass the scenario options from the globally loaded config
    scenario_options_config = PRERUN_CONFIG$selectors$scenario$options
  )

  table_panel_server(
    "prerun",
    settings = reactive({
      get_control_settings(input, "prerun")
    })
  )

  plot_panel_server(
    "custom",
    settings = reactive({
      get_control_settings(input, "custom")
    })
  )

  table_panel_server(
    "custom",
    settings = reactive({
      get_control_settings(input, "custom")
    })
  )

  # Initialize display setup (replaces add.display.event.handlers)
  initialize_display_setup(session, input)

  # Source and initialize page handlers (these now handle their own display events)
  # Sourcing them here defers loading until the server function runs
  print("[APP Server] Sourcing prerun server logic...")
  source("src/ui/components/pages/prerun/index.R")
  # Pass global config to handlers
  initialize_prerun_handlers(input, output, session, plot_state, config = PRERUN_CONFIG)

  print("[APP Server] Sourcing custom server logic...")
  source("src/ui/components/pages/custom/index.R")
  # Pass global config to handlers
  initialize_custom_handlers(input, output, session, plot_state, config = CUSTOM_CONFIG)

  # Initialize state synchronization for both pages
  create_visualization_sync("prerun", session)
  create_visualization_sync("custom", session)

  # Log that sync is initialized
  message("=== Visualization state sync initialized for all pages ===")

  # Initialize contact handlers using new framework-agnostic handler
  initialize_contact_handler(input, output, session)

  # Periodic cleanup of old simulations and cache
  observe({
    # Get cleanup interval from config with fallback
    cleanup_interval <- 600000 # Default: 10 minutes

    tryCatch(
      {
        cleanup_config <- get_component_config("state_management")$cleanup
        if (!is.null(cleanup_config$cleanup_interval)) {
          cleanup_interval <- cleanup_config$cleanup_interval
        }
      },
      error = function(e) {
        print(paste0("[APP] Error loading cleanup config: ", e$message, ". Using default interval."))
      }
    )

    invalidateLater(cleanup_interval)
    print("[APP] Running scheduled cleanup")

    # Run cleanup on unified cache manager
    print("[APP] Running unified cache cleanup")
    if (!is.null(cache_manager)) {
      tryCatch(
        {
          cache_manager$cleanup(force = FALSE)
        },
        error = function(e) {
          print(sprintf("[APP] Error in unified cache cleanup: %s", e$message))
        }
      )
    } else {
      print("[APP] Skipping unified cache cleanup (manager not initialized)")
    }

    # For backward compatibility, also run old cleanup
    print("[APP] Running simulation cleanup")
    get_store()$cleanup_old_simulations(force = FALSE)
  })
}

# Run the application
shinyApp(ui = ui, server = server, onStart = function() {
  pkg_env <- asNamespace("jheem2")
  internal_fns <- ls(pkg_env, all.names = TRUE)

  for (fn in internal_fns) {
    if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
      assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
    }
  }
})
