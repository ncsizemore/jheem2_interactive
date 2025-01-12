#' Base panel component
#' @param id Panel identifier
#' @param config Panel configuration from layout.yaml
#' @param content Panel content
#' @param position "left" or "right"
create_panel <- function(id, config, content, position = "left") {
    ns <- NS(id)
    
    tags$div(
        id = ns(config$id),
        class = sprintf("panel-section side-panel %s-panel", position),
        
        # Header
        tags$div(
            class = "panel-header",
            config$header
        ),
        
        # Content
        tags$div(
            class = "panel-content",
            content
        ),
        
        # Toggle button if collapsible
        if (config$collapsible) {
            tags$button(
                id = ns(sprintf("toggle-%s", position)),
                class = sprintf("toggle-button toggle-%s", position),
                icon(sprintf("chevron-%s", if(position == "left") "left" else "right"))
            )
        }
    )
}