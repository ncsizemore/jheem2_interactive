# Load configuration
config <- yaml::read_yaml("config/layout.yaml")

#' Creates the main layout for the pre-run interventions page
create_prerun_layout <- function() {
    tags$div(
        class = "prerun-container three-panel-container",
        id = "prerun-page",
        
        # Left panel using base component
        create_panel(
            id = "intervention",
            config = config$layout$panels$left,
            content = create_intervention_content(),
            position = "left"
        ),
        
        # Main visualization
        create_visualization_panel(),
        
        # Right panel using base component
        create_panel(
            id = "settings",
            config = config$layout$panels$right,
            content = create.plot.control.panel('prerun'),
            position = "right"
        )
    )
}

#' Creates the intervention panel content
create_intervention_content <- function() {
    tagList(
        # Location selector
        create.location.selector('prerun'),
        
        # Conditional intervention options
        conditionalPanel(
            condition = sprintf("input.int_location_%s !== 'none'", 'prerun'),
            tags$div(
                class = "intervention-options",
                create.intervention.aspect.selector('prerun'),
                create.target.population.selector('prerun'),
                create.time.frame.selector('prerun'),
                create.intensity.selector('prerun'),
                tags$hr(),
                create.generate.projections.button('prerun')
            )
        )
    )
}

#' Creates the main visualization panel
create_visualization_panel <- function() {
    tags$div(
        class = "visualization-panel panel-section",
        id = "visualization-area",
        create_plot_panel('prerun')
    )
}