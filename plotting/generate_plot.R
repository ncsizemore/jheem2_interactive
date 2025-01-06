# Plot functionality ####
##---------------------------------------------##
##-- THE MAIN PLOT/TABLE GENERATING FUNCTION --##
##        (Plus a convenience wrapper)         ##
##---------------------------------------------##

do.prepare.plot.and.table <- function(session,
                                      input,
                                      type=c('prerun', 'custom')[1],
                                      intervention.settings)
{
    prepare.plot.and.table(session=session,
                           main.settings = get.main.settings(input, type),
                           control.settings = get.control.settings(input, type),
                           intervention.settings=intervention.settings)
}

prepare.plot.and.table <- function(session,
                                   main.settings,
                                   control.settings,
                                   intervention.settings)
{
    tryCatch({
        simset = get(load('simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata'))
        
        #--Make the plot --#
        plot.results = prepare.simulations.plot.and.table(
            simset = simset,
            outcomes = control.settings$outcomes,
            facet.by = control.settings$facet.by,
            summary.type = control.settings$summary.type
        )
        
        #-- Store Settings --#
        plot.results$main.settings = main.settings
        plot.results$control.settings = control.settings
        plot.results$int.settings = intervention.settings
        
        return(plot.results)
    },
    error = function(e){
        print("Error generating figure!")
        browser()
        return(NULL)
    })
}

prepare.simulations.plot.and.table <- function(simset,
                                               outcomes,
                                               facet.by,
                                               summary.type)
{
    # Right now, the simset doesn't have a name
    plot.data = prepare.plot(list(simset=simset), outcomes=outcomes, facet.by=facet.by, summary.type=summary.type)
    return (list(plot=plot.data))
}