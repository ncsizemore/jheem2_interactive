
##------------------------------##
##-- CREATE THE DISPLAY PANEL --##
##------------------------------##

create.display.panel <- function(suffix)
{
    tabsetPanel(
        id=paste0('nav_', suffix),
        tabPanel(
            title="Figure",
            uiOutput(outputId = paste0('figure_', suffix), class='fill_div')
        )
    )  
}

##-----------------------------##
##-- MANIPULATE THE CONTENTS --##
##-----------------------------##

set.display <- function(input, output, suffix, plot.and.table)
{
    set.plot(input, output, suffix, plot.and.table)
    # set.table(input, output, suffix, plot.and.table$change.df)
    set.intervention.panel(output, suffix, 'intervention name here') #plot.and.table[['intervention']])
}

clear.display <- function(input, output, suffix)
{
    clear.plot(output, input, suffix)
    # clear.table(output, input, suffix)
    clear.intervention.panel(output, input, suffix)
}

set.plot <- function(input,
                     output,
                     suffix,
                     plot.and.table)
{
    print(paste("set.plot called with suffix:", suffix))
    print("plot_and_table contents:")
    str(plot.and.table)
    
    holder.id = paste0('figure_', suffix)
    plot.id = get.plot.id(suffix)
    
    print(paste("Holder ID:", holder.id))
    print(paste("Plot ID:", plot.id))
    holder.id = paste0('figure_', suffix)
    plot.id = get.plot.id(suffix)
    
    display.size = get.display.size(input, suffix)
    holder.height = display.size$height - DISPLAY_Y_CUSHION
    holder.width = display.size$width
    figure.size = get.figure.size(plot.and.table,
                                  input=input,
                                  suffix=suffix)
    height = figure.size$height
    width = figure.size$width

    print(paste0('holder.height=', holder.height, ', holder.width=', holder.width, ', figure height=', height, ', figure width=', width))

    output[[holder.id]] = renderUI(tags$div(class='plot_holder',
                                            style=paste0('max-height: ', holder.height, 'px;',
                                                         'max-width: ', holder.width, 'px;'),
                                            withSpinner(type=1,plotOutput(outputId = plot.id,
                                                                          height=paste0(height, 'px')))#,
                                                                          # width=paste0(width, 'px')))
    ))

    do.render.plot(input=input,
                   output=output,
                   suffix=suffix,
                   plot=plot.and.table)
}

do.render.plot <- function(input,
                           output,
                           suffix,
                           plot.and.table)
{
    print(paste("do.render.plot called with suffix:", suffix))
    print("Control settings:")
    str(plot.and.table$control.settings)
    
    control.settings = plot.and.table$control.settings
    settings = calculate.optimal.nrows.and.label.size(plot.and.table, input, suffix)
    
    the.plot = execute.simplot(prepared.plot.data=plot.and.table$plot,
                               outcomes=control.settings$outcomes,
                               facet.by=control.settings$facet.by,
                               summary.type=control.settings$summary.type,
                               n.facet.rows=settings$nrows)
    
    plot.id = get.plot.id(suffix)
    output[[plot.id]] = renderPlot(the.plot)
}

get.plot.id <- function(suffix) {
    paste0(suffix, "-mainPlot")  # This will match the HTML structure
}

set.intervention.panel <- function(output,
                                   suffix,
                                   intervention)
{
    panel.id = paste0('selected_intervention_', suffix)
    if (is.null(intervention))
        output[[panel.id]] = renderUI(
            tags$div("No intervention has been set")
        )
    else
        output[[panel.id]] = renderUI(
            tags$div("summary of intervention here?")
        )
}

set.redraw.button.enabled <- function(input,
                                      suffix,
                                      enabled)
{
    if (enabled)
    {
        shinyjs::enable(paste0('redraw_', suffix))
    }
    else
    {
        shinyjs::disable(paste0('redraw_', suffix))
    }
}

##----------##
##-- NCOL --##
##----------##

MIN.PANEL.WIDTH = 300
MIN.PANEL.HEIGHT = 280

get.figure.size <- function(plot.and.table,
                            input, suffix,
                            ideal.w.h.ratio=1.5,
                            y.cushion=DISPLAY_Y_CUSHION+2*FIGURE.PADDING)
{
    display.size = get.display.size(input, suffix)
    settings = do.calculate.optimal.nrows(n.panels = get.num.panels.to.plot(plot.and.table$control.settings),
                                          display.width = display.size$width,
                                          display.height = display.size$height,
                                          ideal.w.h.ratio = ideal.w.h.ratio)
    print(paste0("get.figure.size claims the display size width is ", display.size$width))
    list(width=display.size$width,
         height=max(display.size$height-y.cushion,
                    settings$nrows * MIN.PANEL.HEIGHT))

}

calculate.optimal.nrows.and.label.size <- function(plot.and.table,
                                                   input, suffix,
                                                   ideal.w.h.ratio=1.5)
{
    display.size = get.display.size(input, suffix)
    settings = do.calculate.optimal.nrows(n.panels = get.num.panels.to.plot(plot.and.table$control.settings),
                                          display.width = display.size$width,
                                          display.height = display.size$height,
                                          ideal.w.h.ratio = ideal.w.h.ratio)
    
    # settings$label.size=do.calculate.label.height(display.size$height, settings$nrows)
    
    settings
}

DEFAULT.DISPLAY.WIDTH = 1366-20
DEFAULT.DISPLAY.HEIGHT = 784-100
do.calculate.optimal.nrows <- function(n.panels,
                                       display.width,
                                       display.height,
                                       ideal.w.h.ratio=1.5)
{
    if (length(display.width)==0)
    {
        print("NOTE: Using default display width")
        display.width = DEFAULT.DISPLAY.WIDTH
    }
    if (length(display.height)==0)
    {
        print("NOTE: Using default display width")
        display.height = DEFAULT.DISPLAY.HEIGHT
    }
    # browser()
    
    possible.n.col = 1:n.panels
    possible.n.row = ceiling(n.panels / possible.n.col)
    
    possible.widths = display.width / possible.n.col
    possible.heights = display.height / possible.n.row
    
    possible.ratios = possible.widths/possible.heights
    ratio.diff = abs(possible.ratios - ideal.w.h.ratio)
    best.mask = ratio.diff == min(ratio.diff)
    
    best.fit.nrows = possible.n.row[best.mask][1]
    best.fit.ncols = ceiling(n.panels / best.fit.nrows)
    
    best.fit.panel.width = display.width / best.fit.ncols
    if (best.fit.panel.width < MIN.PANEL.WIDTH)
    {
        min.width.ncols = max(1, floor(display.width / MIN.PANEL.WIDTH))
        min.width.nrows = ceiling(n.panels / min.width.ncols)
        
        list(nrows=min.width.nrows,
             ncols=min.width.ncols)
    }
    else
    {
        list(nrows=best.fit.nrows,
             ncols=best.fit.ncols)
    }
}

get.num.panels.to.plot <- function(control.settings)
{
    selected.outcomes = control.settings$outcomes
    n.selected.outcomes = length(selected.outcomes)
    
    facet.by = control.settings$facet.by
    if (is.null(facet.by))
        n.facet = 1
    else
        n.facet = sapply(facet.by, function(ff){
            length(DIMENSION.VALUES.2[[ff]]$values)
        })
    
    n.selected.outcomes * prod(n.facet)
}

#' Show visualization with debugging
#' @param input Shiny input object
#' @param output Shiny output object
#' @param page_type String: page type (e.g., "prerun" or "custom")
#' @param simset Simulation data to display
show_visualization <- function(input, output, page_type, simset) {
    print("Starting show_visualization")
    
    # Get control settings with defaults if needed
    control_settings <- get.control.settings(input, page_type)
    print("Control settings:")
    print(control_settings)
    
    # Show the visualization area
    print("Attempting to show visualization area")
    panel_id <- paste0("display-panel-", page_type)
    print(paste("Showing panel:", panel_id))
    shinyjs::show(id = panel_id, anim = TRUE)
    
    # Initialize display size inputs if needed
    if (is.null(input[[paste0('left_width_', page_type)]])) {
        print("Initializing panel widths")
        updateTextInput(session, 
                        paste0('left_width_', page_type), 
                        value = LEFT.PANEL.SIZE[page_type]
        )
        updateTextInput(session,
                        paste0('right_width_', page_type),
                        value = RIGHT.PANEL.SIZE[page_type]
        )
    }
    
    # Create display data
    display_data <- list(
        plot = simset,
        control.settings = control_settings
    )
    
    print("Calling set.display")
    # Update the display
    set.display(input, output, page_type, display_data)
    print("Finished show_visualization")
}

# Add at the bottom of display_helpers.R
toggle_visualization <- function(show = FALSE) {
    if (show) {
        shinyjs::show("visualization-area")
    } else {
        shinyjs::hide("visualization-area")
    }
}