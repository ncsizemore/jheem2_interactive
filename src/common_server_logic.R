# src/common_server_logic.R
# Defines a function to initialize common server-side logic for dedicated Shiny apps.

initialize_common_server_logic <- function(input, output, session) {
    print("[COMMON_SERVER_LOGIC] Initializing common server elements...")

    # --- 1. Future Plan ---
    future::plan(multisession)
    print("[COMMON_SERVER_LOGIC] Future plan set to multisession.")

    # --- 2. Model Status Management ---
    # Create error boundary for model loading (assuming get_store is available via common_startup.R)
    # and create_error_boundary is also available.
    model_boundary <- create_error_boundary(
        session,
        output,
        "global_model", # A more generic ID for common logic
        "model_spec",
        state_manager = get_store() # get_store() comes from src/ui/state/store.R
    )

    # Create model status manager (assuming create_model_status_manager is available)
    model_status <- create_model_status_manager(session, model_boundary)

    # Make the model status functions available to other components via session$userData
    session$userData$load_model_spec <- model_status$load_model_spec
    session$userData$is_model_spec_loaded <- model_status$is_loaded
    print("[COMMON_SERVER_LOGIC] Model status manager initialized and functions set in session$userData.")

    # Auto-load the model specification after UI is rendered.
    # This behavior might need to be conditional based on app type (prerun vs custom)
    # and will be controlled by the app-specific server function calling this.
    # For now, we include it, and the app-specific server can decide to call load_model_spec.
    # session$onFlushed(function() {
    #   message("[COMMON_SERVER_LOGIC] UI rendered. Model spec auto-load is app-specific.")
    #   # model_status$load_model_spec() # App-specific server will call this if needed
    # })


    # --- 3. Cache Initialization ---
    # (Assuming get_component_config and get_cache_manager are available via common_startup.R)
    cache_config <- get_component_config("caching")
    print("[COMMON_SERVER_LOGIC] Starting unified cache manager initialization...")
    # Directory creation logic from app.R
    cache_dir_base <- "cache"
    cache_dirs <- c(cache_dir_base, file.path(cache_dir_base, "onedrive"), file.path(cache_dir_base, "simulations"))
    for (dir_path in cache_dirs) {
        if (!dir.exists(dir_path)) {
            print(sprintf("[COMMON_SERVER_LOGIC] Creating cache directory: %s", dir_path))
            dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
        }
    }

    cache_manager <- tryCatch(
        {
            cm <- get_cache_manager()
            print("[COMMON_SERVER_LOGIC] Unified cache manager obtained.")
            cm
        },
        error = function(e) {
            print(sprintf("[COMMON_SERVER_LOGIC] Error initializing unified cache manager: %s. Fallback may occur.", e$message))
            NULL
        }
    )
    session$userData$cache_manager <- cache_manager # Make it available if needed

    # For backward compatibility, also initialize old caches
    initialize_caches(cache_config) # initialize_caches from src/data/cache.R
    print("[COMMON_SERVER_LOGIC] Caches initialized.")


    # --- 4. Download Manager & Progress UI ---
    # (Assuming create_download_manager is available via common_startup.R)
    output$download_progress_container <- renderUI({
        tags$div(id = "download-progress-container", class = "download-progress-container")
    })
    DOWNLOAD_MANAGER_INSTANCE <- create_download_manager(session, output)
    session$userData$DOWNLOAD_MANAGER <- DOWNLOAD_MANAGER_INSTANCE # Make it available
    print("[COMMON_SERVER_LOGIC] Download manager initialized and progress UI set up.")


    # --- 5. UI Messenger ---
    # (Assuming create_ui_messenger is available via common_startup.R)
    UI_MESSENGER_INSTANCE <- create_ui_messenger(session)
    session$userData$ui_messenger <- UI_MESSENGER_INSTANCE
    print("[COMMON_SERVER_LOGIC] UI messenger initialized.")


    # --- 6. Progress Components ---
    # (Assuming init_progress_components is available via common_startup.R)
    progress_components <- init_progress_components(input, output, session)
    session$userData$progress_components <- progress_components # Make them available
    print("[COMMON_SERVER_LOGIC] Progress components initialized.")
    # Note: Review if init_progress_components has page-specific aspects from app.R
    # that might need further refactoring for true commonality.


    # --- 7. Display Setup ---
    # (Assuming initialize_display_setup is available via common_startup.R)
    initialize_display_setup(session, input)
    print("[COMMON_SERVER_LOGIC] Display setup initialized.")


    # --- 8. Periodic Cleanup ---
    observe({
        cleanup_interval_ms <- 600000 # Default: 10 minutes
        tryCatch(
            {
                mgmt_config <- get_component_config("state_management")
                if (!is.null(mgmt_config$cleanup) && !is.null(mgmt_config$cleanup$cleanup_interval)) {
                    cleanup_interval_ms <- mgmt_config$cleanup$cleanup_interval
                }
            },
            error = function(e) {
                print(paste0("[COMMON_SERVER_LOGIC] Error loading cleanup interval from config: ", e$message))
            }
        )

        invalidateLater(cleanup_interval_ms)
        print("[COMMON_SERVER_LOGIC] Running scheduled cleanup...")
        if (!is.null(session$userData$cache_manager)) {
            tryCatch(
                {
                    session$userData$cache_manager$cleanup(force = FALSE)
                    print("[COMMON_SERVER_LOGIC] Unified cache cleanup executed.")
                },
                error = function(e) {
                    print(sprintf("[COMMON_SERVER_LOGIC] Error in unified cache cleanup: %s", e$message))
                }
            )
        }
        # Old simulation cleanup (assuming get_store is available)
        get_store()$cleanup_old_simulations(force = FALSE)
        print("[COMMON_SERVER_LOGIC] Old simulation store cleanup executed.")
    })
    print("[COMMON_SERVER_LOGIC] Periodic cleanup observer set.")

    print("[COMMON_SERVER_LOGIC] Common server elements initialization complete.")
    # Return any objects that the calling server function might need, e.g., model_status
    return(list(
        model_status = model_status,
        cache_manager = session$userData$cache_manager # or cache_manager directly
        # DOWNLOAD_MANAGER = DOWNLOAD_MANAGER_INSTANCE, # if needed directly
        # UI_MESSENGER = UI_MESSENGER_INSTANCE # if needed directly
    ))
}

print("[COMMON_SERVER_LOGIC] Script loaded. initialize_common_server_logic() is defined.")
