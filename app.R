library(shiny)
library(shinyBS)
library(shinyjs)
library(shinycssloaders)
library(cachem)
library(magrittr)

# Source configuration system
source('config/load_config.R')

# Source components and helpers
source('components/common/popover.R')  # Updated path
source('components/display/plot_panel.R')
source('components/display/plot_controls.R')
source('components/layout/panel.R')
source('components/selectors/base.R')
source('components/selectors/custom_components.R')
source('components/pages/prerun_interventions.R')
source('components/pages/custom_interventions.R')
source('components/pages/team.R')
source('components/pages/contact.R')
# Source control panel functions
source('ui/control_panel.R')

source('master_settings/options.R')

# Source plotting system
source('plotting/generate_plot.R')
#source('plotting/simplot/prepare_plot.R')
#source('plotting/simplot/execute_plot.R')
#source('components/display/plot.R')


# Source server handlers
source('server/handlers/prerun_handlers.R')
source('server/handlers/custom_handlers.R')
source('server/display_utils.R')

# Source other required files
source('helpers/accordion.R')
source('helpers/concertina.R')
source('helpers/display_size.R')
source('plotting/generate_plot.R')
source('server/display_event_handlers.R')
source('server/contact_handlers.R')

library(jheem2)
source('../jheem_analyses/applications/EHE/ehe_specification.R')

# UI Creation
ui <- function() {
    # Load base configuration
    config <- get_base_config()
    
    
    # Default selections from config
    selected_tab <- config$application$defaults$selected_tab %||% 'custom_interventions'
    app_title <- config$application$name
    
    tags$html(
        style = 'height:100%',
        
        tags$title(app_title),
        
        # Initialize Shiny extensions
        shinyjs::useShinyjs(),
        
        # Load JavaScript extensions
        extendShinyjs(
            script = 'js/layout/panel-controls.js',
            functions = c('ping_display_size', 'ping_display_size_onload', 'set_input_value')
        ),
        extendShinyjs(
            script = 'js/interactions/download_plotly.js',
            functions = c('download_plotly')
        ),
        extendShinyjs(
            script = 'js/interactions/sounds.js',
            functions = c('chime', 'chime_if_checked')
        ),
        extendShinyjs(
            script = 'js/interactions/accordion.js',
            functions = c('trigger_accordion')
        ),
        extendShinyjs(
            script = 'js/interactions/concertina.js',
            functions = c('trigger_concertina')
        ),
        
        
        
        # Load CSS files based on config
        tags$head(

            # Load base styles
            tags$link(
                rel = "stylesheet",
                type = "text/css",
                href = config$theme$styles$base
            ),
            
            # Load layout styles
            lapply(config$theme$styles$layout, function(style) {
                tags$link(
                    rel = "stylesheet",
                    type = "text/css",
                    href = style
                )
            }),
            
            # Load component styles
            lapply(config$theme$styles$components, function(style) {
                tags$link(
                    rel = "stylesheet",
                    type = "text/css",
                    href = style
                )
            }),
            
            # Load theme styles
            lapply(config$theme$styles$themes, function(style) {
                tags$link(
                    rel = "stylesheet",
                    type = "text/css",
                    href = style
                )
            }),
            
            # Load page-specific styles
            lapply(config$theme$styles$pages, function(style) {
                tags$link(
                    rel = "stylesheet",
                    type = "text/css",
                    href = style
                )
            }),
            
            # Load grid styles
            lapply(config$theme$styles$grid, function(style) {
                tags$link(
                    rel = "stylesheet",
                    type = "text/css",
                    href = style
                )
            }),
            
            # Load JavaScript files
            lapply(config$theme$scripts, function(script) {
                tags$script(src = script)
            })
        ),
            
        
        tags$body(
            style = 'height:100%;',
            navbarPage(
                id = 'main_nav',
                title = app_title,
                collapsible = FALSE,
                selected = selected_tab,
                
                # Overview tab
                tabPanel(
                    id = 'overview',
                    value = 'overview',
                    title = 'Overview',
                    make_tab_popover(
                        "overview",
                        title = config$pages$overview$popover$title,
                        content = config$pages$overview$popover$content
                    ),
                    includeHTML('html_pages/overview.html')
                ),
                
                # Pre-run tab
                tabPanel(
                    title = 'Pre-Run',
                    value = 'prerun_interventions',
                    create_prerun_layout()
                ),
                
                # Custom tab
                tabPanel(
                    title = 'Custom',
                    value = 'custom_interventions',
                    create_custom_layout()
                ),
                
                # FAQ tab
                tabPanel(
                    title = 'FAQ',
                    value = 'faq',
                    make_tab_popover(
                        "faq",
                        title = config$pages$faq$popover$title,
                        content = config$pages$faq$popover$content
                    ),
                    includeHTML('html_pages/faq.html')
                ),
                
                # About tab
                tabPanel(
                    title = 'About the JHEEM',
                    value = 'about_the_jheem',
                    make_tab_popover(
                        "about_the_jheem",
                        title = config$pages$about$popover$title,
                        content = config$pages$about$popover$content
                    ),
                    includeHTML('html_pages/about.html')
                ),
                
                # Team tab
                tabPanel(
                    title = 'Our Team',
                    value = 'our_team',
                    make_tab_popover(
                        "our_team",
                        title = config$pages$team$popover$title,
                        content = config$pages$team$popover$content
                    ),
                    create_team_content(config)
                ),
                
                # Contact tab
                tabPanel(
                    title = 'Contact Us',
                    value = 'contact_us',
                    make_tab_popover(
                        "contact_us",
                        title = config$pages$contact$popover$title,
                        content = config$pages$contact$popover$content
                    ),
                    create_contact_content(config)
                )
            )
        )
    )
}

# Server function
# In app.R, modify the server function
server <- function(input, output, session) {
    # Create reactive value at server level
    plot_state <- reactiveVal(
        lapply(c('prerun', 'custom'), function(x) NULL) %>% 
            setNames(c('prerun', 'custom'))
    )
    
    # Initialize caches from config
    cache_config <- get_component_config("caching")
    DISK.CACHE.1 <- cachem::cache_disk(
        max_size = cache_config$cache1$max_size,
        evict = cache_config$cache1$evict_strategy
    )
    DISK.CACHE.2 <- cachem::cache_disk(
        max_size = cache_config$cache2$max_size,
        evict = cache_config$cache2$evict_strategy
    )
    
    # Load initial data
    simset <- NULL
    tryCatch({
        load('simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata')
    }, error = function(e) {
        showNotification(
            "Error loading initial simulation data",
            type = "error"
        )
    })
    
    # Initialize UI state
    #shinyjs::hide("visualization-area-prerun")
    #shinyjs::hide("visualization-area-custom")
    #shinyjs::hide("settings-settings-panel")
    #shinyjs::hide("settings-custom-settings-panel")
    
    # Initialize plot panels
    plot_panel_server(
        "prerun",
        data = reactive({ simset }),
        settings = reactive({
            settings <- get.control.settings(input, "prerun")
            settings
        })
    )
    
    plot_panel_server(
        "custom",
        data = reactive({ simset }),
        settings = reactive({
            settings <- get.control.settings(input, "custom")  # Change to dot version
            if (!is.null(settings$outcomes)) {
                settings$outcomes <- intersect(settings$outcomes, simset$outcomes)
            }
            settings
        })
    )
    
    # Add display event handlers with plot_state
    add.display.event.handlers(session, input, output, plot_state)
    
    # Initialize page handlers
    initialize_prerun_handlers(input, output, session, plot_state)
    initialize_custom_handlers(input, output, session, plot_state)
    
    # Add contact handlers
    add.contact.handlers(session, input, output)
}

# Run the application 
shinyApp(ui = ui, server = server)