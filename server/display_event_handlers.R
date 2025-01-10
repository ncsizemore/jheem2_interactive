
##-----------------------------------------##
##-- EVENT HANDLERS FOR UPDATING DISPLAY --##
##-----------------------------------------##
add.display.event.handlers <- function(session, input, output, suffixes=c('prerun', 'custom'))
{
    #--Variables for storing plot/table --#
    plot.and.table.list = lapply(suffixes, function(x){NULL})
    names(plot.and.table.list) = suffixes
    is.first.plot = T
    
    #-- General Handler for Running/Redrawing --#
    do.run = function(suffix,
                      intervention.settings)
    {
        get.display.size(input, 'prerun')
        
        # #-- Lock the appropriate buttons --#
        # lock.cta.buttons(input, called.from.suffix = suffix,
        #                  plot.and.table.list=plot.and.table.list)
        
        # in plotting/generate_plot.R
        new.plot.and.table = do.prepare.plot.and.table(session=session,
                                                       input=input,
                                                       type=suffix,
                                                       intervention.settings=intervention.settings)
        if (!is.null(new.plot.and.table))
        {
            plot.and.table.list[[suffix]] <<- new.plot.and.table
            
            #-- Update the UI --#
            set.display(input, output, suffix, plot.and.table.list[[suffix]])
            sync.buttons.to.plot(input, plot.and.table.list)
        }
        
        # unlock.cta.buttons(input, called.from.suffix = suffix,
        #                    plot.and.table.list=plot.and.table.list)
    }
    
    #-- The Handlers for Generating/Redrawing Pre-Run --#
    observeEvent(input$run_prerun, {
        int.settings = NULL
        do.run(suffix='prerun',
               int.settings)
        # browser()
        simset = get(load("simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata"))
        # library(aws.iam)
        # library(aws.s3)
        # simset = s3load("1.0/12060/1.0_12060_baseline.Rdata", bucket='endinghiv.sims')
    })
    
    observeEvent(input$redraw_prerun, {
        do.run(suffix='prerun',
               intervention.settings = plot.and.table.list$custom$int.settings)
    })
    
    observeEvent(input$run_custom, {
        int.settings = NULL
        do.run(suffix='custom',
               int.settings)
    })
    
    observeEvent(input$redraw_custom, {
        do.run(suffix='custom',
               intervention.settings = plot.and.table.list$custom$int.settings)
    })
    
    #-- Some Initial Set-Up Once Loaded --#
    
    session$onFlushed(function(){
        # This is where the "display_size_" inputs are created (in window.js)
        js$ping_display_size_onload()
        print("flushed")
        # browser()
        js$set_input_value(name='left_width_prerun', value=as.numeric(LEFT.PANEL.SIZE['prerun']))
        js$set_input_value(name='right_width_prerun', value=0)
        js$set_input_value(name='left_width_custom', value=as.numeric(LEFT.PANEL.SIZE['custom']))
        js$set_input_value(name='right_width_custom', value=0)
        
        # lapply(names(plot.and.table.list), 
        #        clear.display,
        #        input=input,
        #        output=output)
        # 
        # Sync up
        sync.buttons.to.plot(input, plot.and.table.list)
        
    }, once=T)
    
    #-- Resize Listener --#
    
    handle.resize <- function(suffixes)
    {
        print("called handle resize")
        lapply(suffixes, function(suffix){
            display.size = get.display.size(input, suffix)
            if (!is.null(plot.and.table.list[[suffix]]))
            {
                set.display(input=input,
                            output=output,
                            suffix=suffix,
                            plot.and.table=plot.and.table.list[[suffix]])
            }
        })
    }
    
    # These are all made in www/window.sizes.js, I believe
    observeEvent(input$display_size_prerun, handle.resize('prerun'))
    observeEvent(input$display_size_custom, handle.resize('custom'))
    observeEvent(input$left_width_prerun, handle.resize('prerun'))
    observeEvent(input$right_width_prerun, handle.resize('prerun'))
    observeEvent(input$left_width_custom, handle.resize('custom'))
    observeEvent(input$right_width_custom, handle.resize('custom'))
    
    # observeEvent(input$main_nav, {
    #     js$ping_display_size() 
    # })
    
}

##-- ENABLING AND DISABLING --##

sync.buttons.to.plot <- function(input, plot.and.table.list)
{
    for (suffix in names(plot.and.table.list))
    {
        enable = !is.null(plot.and.table.list[[suffix]])
        
        set.redraw.button.enabled(input, suffix, enable)
        
        # set.share.enabled(input, suffix, enable)
    }
}