# x
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

## USE THIS LINE IF DEVELOPING CSS
renv::refresh()

library(shiny)
library(shinyBS)
library(shinyjs)
library(shinycssloaders) # used for "withSpinner"

#-- OTHER --#
source('env.R')

#-- MASTER SETTINGS --#
source('master_settings/options.R') # later will have specification generate this stuff.

#-- PLOT INTERFACE --#
source('plotting/generate_plot.R')

#-- HELPERS --#
source('helpers/accordion.R')
source('helpers/concertina.R')
source('helpers/display_size.R')

#-- SERVER FILES --#
source('server/contact_handlers.R')
source('server/display_event_handlers.R')

#-- UI FILES --#
source('ui/popovers.R')
source('ui/contact.R')
source('ui/display_helpers.R')
source('ui/prerun_interventions.R')
source('ui/custom_interventions.R')
source('ui/team.R')
source('ui/control_panel.R')

#-- SPECIFICATION AND MODEL --#
# source('../jheem_analyses/source_code.R')
library(jheem2)
source('../jheem_analyses/applications/EHE/ehe_specification.R') # ONLY WAY?'

ui <- function() {
    
    selected.tab = 'custom_interventions'
    app.title = 'jheem2'
    
    #----------------------------#
    #-- RENDER THE MAIN UI TAB --#
    #----------------------------#
    
    tags$html(style='height:100%',
              
              tags$title("JHEEM 2 - Ending HIV"),
              
              # Add js scripts to shinyjs
              shinyjs::useShinyjs(),
              # extendShinyjs(script = 'window_sizes.js', functions = c('ping_display_size', 'ping_display_size_onload', 'set_input_value')),
              extendShinyjs(script = 'window_sizes2.js', functions = c('ping_display_size', 'ping_display_size_onload', 'set_input_value')),
              extendShinyjs(script = 'download_plotly.js', functions = c('download_plotly')),
              extendShinyjs(script = 'sounds.js', functions = c('chime', 'chime_if_checked')),
              extendShinyjs(script = 'accordion.js', functions = c('trigger_accordion')),
              extendShinyjs(script = 'concertina.js', functions = c('trigger_concertina')),
              # extendShinyjs(script = 'do_the_thing.js', functions = c('do_the_thing', 'ping_display_size_onload')),
              
              # Add CSS Files
              tags$head(
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/main_layout.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "display_panel.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "custom_controls.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "plot_controls.css"),
                  #tags$link(rel = "stylesheet", type = "text/css", href = "box_colors.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "color_schemes/color_scheme_jh.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "accordion.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/chevrons.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/errors.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "notifications.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/about.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/overview.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/contact.css"),
                  tags$link(rel = "stylesheet", type = "text/css", href = "css/Andrew_additions.css"), ## added for trying CSS grid
                  
                  # tags$script(src = 'window_sizes.js'),
                  # tags$script(src = 'window_sizes2.js'),
                  tags$script(src = 'accordion.js'),
                  tags$script(src = 'setup_tooltips.js'),
                  tags$script(src = 'box_expansion.js'),
                  tags$script(src = 'copy_to_clipboard.js'),
                  tags$script(src = 'concertina.js'),
                  # tags$script(src = 'do_the_thing.js')
              ),
              
              
              tags$body(style='height:100%;',
                        navbarPage(
                            id = 'main_nav',
                            title = app.title,
                            collapsible = F,
                            selected = selected.tab,
                            
                            
                            tabPanel(
                                id = 'overview',
                                value = 'overview',
                                title = 'Overview',
                                make.tab.popover("overview", title=OVERVIEW.POPOVER.TITLE, content=OVERVIEW.POPOVER),
                                includeHTML('html_pages/overview.html')
                            ),
                            tabPanel(
                                title = 'Pre-Run',
                                value = 'prerun_interventions',
                                make.prerun.content()
                            ),
                            tabPanel(
                                title = 'Custom',
                                value = 'custom_interventions',
                                make.custom.content()
                            ),
                            tabPanel(
                                title = 'FAQ',
                                value = 'faq',
                                make.tab.popover("faq", title=FAQ.POPOVER.TITLE, content=FAQ.POPOVER),
                                includeHTML('html_pages/faq.html')
                            
                            ),
                            tabPanel(
                                title = 'About the JHEEM',
                                value = 'about_the_jheem',
                                make.tab.popover("about_the_jheem", title=ABOUT.POPOVER.TITLE, content=ABOUT.POPOVER),
                                includeHTML('html_pages/about.html')
                            ),
                            tabPanel(
                                title = 'Our Team',
                                value = 'our_team',
                                make.tab.popover("our_team", title=OUR.TEAM.POPOVER.TITLE, content=OUR.TEAM.POPOVER),
                                TEAM.CONTENT # from ui/team.R
                                # includeHTML('html_pages/team.html')
                            ),
                            tabPanel(
                                title = 'Contact Us',
                                value = 'contact_us',
                                make.tab.popover("contact_us", title=CONTACT.POPOVER.TITLE, content=CONTACT.POPOVER),
                                CONTACT.CONTENT
                            )
                        ) # </navbarPage>
              ) #</body>
    )
}


##----------------------##
##-- SET UP THE CACHE --##
##----------------------##
#shinyOptions(cache=diskCache(file.path(dirname(tempdir()), "myapp-cache")))
DISK.CACHE.1 = cachem::cache_disk(max_size = 1e9, evict='lru')
DISK.CACHE.2 = cachem::cache_disk(max_size = 1e9, evict='lru')

server <- function(input, output, session) {
    ##--------------------##    
    ##-- INITIAL SET-UP --##
    ##--------------------##
    
    # Print an initial message - useful for debugging on shinyapps.io servers
    print(paste0("Launching server() function - ", Sys.time()))
    
    #-- Make our session cache --#
    # mem.cache = cachem::cache_mem(max_size = 300e6, evict='lru')
    # cache = create.multi.cache(mem.cache=mem.cache,
    #                            disk.caches=list(DISK.CACHE.1, DISK.CACHE.2),
    #                            directories = 'sim_cache')
    
    ##-----------------------------------------##
    ##-- EVENT HANDLERS FOR UPDATING DISPLAY --##
    ##-----------------------------------------##
    
    # in server/display_event_handlers.R
    add.display.event.handlers(session, input, output)
    
    ##------------------##
    ##-- CONTACT FORM --##
    ##------------------##
    
    add.contact.handlers(session, input, output)
    
}

# Run the application 
shinyApp(ui = ui, server = server)
