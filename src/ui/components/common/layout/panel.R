# src/ui/components/common/layout/panel.R

#' Create a panel component
#' @param id Panel identifier
#' @param type Panel type ("left" or "right")
#' @param config Configuration from get_page_complete_config()
#' @param content Panel content
create_panel <- function(id, type, config, content) {
    if (id == "settings") {
        print("=== Creating Right Panel ===")
        print(paste("Panel ID:", id))
        print(paste("Panel Type:", type))
    }

    # Validate inputs
    validate_panel_inputs(id, type, config)

    # Get panel-specific config
    panel_config <- config$panels[[type]]
    theme_config <- config$theme

    # Generate namespaced ID
    ns <- NS(id)

    # Build CSS classes
    classes <- build_panel_classes(type, panel_config)

    # Create panel structure with configuration
    tags$div(
        id = ns(panel_config$id),
        class = classes,
        style = build_panel_styles(panel_config, theme_config),

        # Header with configured styles
        tags$div(
            class = "panel-header",
            style = build_header_styles(theme_config),
            panel_config$header
        ),
        
        # Add panel description if provided
        if (!is.null(panel_config$description)) {
            tags$div(
                class = "panel-description",
                style = "padding: var(--spacing-sm); border-bottom: 1px solid var(--color-gray-200); background-color: var(--color-gray-50); font-size: var(--font-size-sm);",
                panel_config$description
            )
        },

        # Content wrapper with configured styles
        tags$div(
            class = "panel-content",
            style = build_content_styles(theme_config),
            content
        ),

        # Configurable toggle button
        if (panel_config$collapsible) {
            create_panel_toggle(ns, type, theme_config)
        }
    )
}

#' Validate panel creation inputs
#' @param id Panel identifier
#' @param type Panel type
#' @param config Panel configuration
#' @return TRUE if valid, throws error if invalid
validate_panel_inputs <- function(id, type, config) {
    # Check required parameters
    if (is.null(id) || !is.character(id)) {
        stop("Panel ID must be a character string")
    }

    if (!type %in% c("left", "right")) {
        stop("Panel type must be 'left' or 'right'")
    }

    # Validate configuration
    if (is.null(config$panels) || is.null(config$panels[[type]])) {
        stop(sprintf("Missing configuration for %s panel", type))
    }

    required_fields <- c("id", "header", "width", "collapsible")
    missing <- setdiff(required_fields, names(config$panels[[type]]))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required panel configuration fields: %s",
            paste(missing, collapse = ", ")
        ))
    }

    TRUE
}

#' Build panel CSS classes
#' @param type Panel type
#' @param panel_config Panel-specific configuration
#' @return String of CSS classes
build_panel_classes <- function(type, panel_config) {
    classes <- c(
        "panel-section",
        "side-panel",
        sprintf("%s-panel", type)
    )

    # Add any custom classes from config
    if (!is.null(panel_config$classes)) {
        classes <- c(classes, panel_config$classes)
    }

    paste(classes, collapse = " ")
}

#' Build panel inline styles
#' @param panel_config Panel-specific configuration
#' @param theme_config Theme configuration
#' @return CSS style string
build_panel_styles <- function(panel_config, theme_config) {
    styles <- list()

    # Width from panel config
    if (!is.null(panel_config$width)) {
        styles$width <- sprintf("%dpx", panel_config$width)
    }

    # Colors from theme
    if (!is.null(theme_config$colors)) {
        styles$backgroundColor <- theme_config$colors$background
        styles$borderColor <- theme_config$colors$border
    }

    # Convert to CSS string
    style_strings <- mapply(
        function(name, value) sprintf("%s: %s;", name, value),
        names(styles),
        styles
    )

    paste(style_strings, collapse = " ")
}

#' Build header styles
#' @param theme_config Theme configuration
#' @return CSS style string
build_header_styles <- function(theme_config) {
    styles <- list()

    # Colors
    if (!is.null(theme_config$colors)) {
        styles$backgroundColor <- theme_config$colors$primary
    }

    # Spacing
    if (!is.null(theme_config$spacing$padding)) {
        styles$padding <- sprintf("%dpx", theme_config$spacing$padding)
    }

    # Convert to CSS string
    style_strings <- mapply(
        function(name, value) sprintf("%s: %s;", name, value),
        names(styles),
        styles
    )

    paste(style_strings, collapse = " ")
}

#' Build content styles
#' @param theme_config Theme configuration
#' @return CSS style string
build_content_styles <- function(theme_config) {
    styles <- list()

    # Spacing
    if (!is.null(theme_config$spacing$padding)) {
        styles$padding <- sprintf("%dpx", theme_config$spacing$padding)
    }

    # Convert to CSS string
    style_strings <- mapply(
        function(name, value) sprintf("%s: %s;", name, value),
        names(styles),
        styles
    )

    paste(style_strings, collapse = " ")
}

#' Create panel toggle button
#' @param ns Namespace function
#' @param type Panel type
#' @param theme_config Theme configuration
#' @return Shiny tag object
create_panel_toggle <- function(ns, type, theme_config) {
    toggle_icon <- if (type == "left") "chevron-left" else "chevron-right"

    tags$button(
        id = ns(sprintf("toggle-%s", type)),
        class = sprintf("toggle-button toggle-%s", type),
        style = build_toggle_styles(theme_config),
        icon(toggle_icon)
    )
}

#' Build toggle button styles
#' @param theme_config Theme configuration
#' @return CSS style string
build_toggle_styles <- function(theme_config) {
    styles <- list()

    # Colors
    if (!is.null(theme_config$colors)) {
        styles$backgroundColor <- theme_config$colors$primary
        styles$borderColor <- theme_config$colors$border
    }

    # Convert to CSS string
    style_strings <- mapply(
        function(name, value) sprintf("%s: %s;", name, value),
        names(styles),
        styles
    )

    paste(style_strings, collapse = " ")
}

#' Initialize panel state management
#' @param id Panel identifier
#' @param session Shiny session object
#' @param config Panel configuration
initialize_panel <- function(id, session, config) {
    # Set up reactive values for panel state
    panel_state <- reactiveVal(list(
        visible = config$defaultVisible,
        width = config$width
    ))

    # Return state management functions
    list(
        get_state = panel_state,
        toggle = function() {
            current <- panel_state()
            current$visible <- !current$visible
            panel_state(current)
        },
        set_width = function(width) {
            current <- panel_state()
            current$width <- width
            panel_state(current)
        }
    )
}
