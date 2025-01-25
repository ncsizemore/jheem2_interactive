# In generate_plot.R

# Source required files
source('ui/control_panel.R')

#' Prepare plot and table with provided settings
#' @param session Shiny session object
#' @param input Shiny input object
#' @param type Type of display ('prerun' or 'custom')
#' @param intervention.settings Settings for intervention
do.prepare.plot.and.table <- function(session,
                                      input,
                                      type=c('prerun', 'custom')[1],
                                      intervention.settings)
{
    print("Starting do.prepare.plot.and.table")
    print(paste("Type:", type))
    
    prepare.plot.and.table(
        session = session,
        main.settings = get.main.settings(input, type),
        control.settings = get.control.settings(input, type),
        intervention.settings = intervention.settings
    )
}

#' Internal function to prepare plot and table
prepare.plot.and.table <- function(session,
                                   main.settings,
                                   control.settings,
                                   intervention.settings)
{
    tryCatch({
        print("Starting prepare.plot.and.table")
        print("Control settings:")
        str(control.settings)
        
        # Check if sim file exists
        sim_file <- 'simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata'
        if (!file.exists(sim_file)) {
            stop(paste("Simulation file not found:", sim_file))
        }
        
        print("Loading simulation file...")
        simset = get(load(sim_file))
        print("Available outcomes in simset:")
        print(simset$outcomes)
        
        print("Preparing plot with settings:")
        print(paste("Outcomes:", paste(control.settings$outcomes, collapse=", ")))
        print(paste("Facet by:", if(is.null(control.settings$facet.by)) "NULL" else paste(control.settings$facet.by, collapse=", ")))
        print(paste("Summary type:", control.settings$summary.type))
        
        #--Make the plot --#
        print("Calling prepare.simulations.plot.and.table...")
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
        print("Error details:")
        print(conditionMessage(e))
        print("Stack trace:")
        print(sys.calls())
        browser()
        return(NULL)
    })
}

prepare.simulations.plot.and.table <- function(simset,
                                               outcomes,
                                               facet.by,
                                               summary.type)
{
  print("In prepare.simulations.plot.and.table")
  print("Inputs:")
  print(paste("- outcomes:", paste(outcomes, collapse=", ")))
  print(paste("- facet.by:", paste(facet.by, collapse=", ")))
  print(paste("- summary.type:", summary.type))
  
  # Right now, the simset doesn't have a name
  plot.data = prepare.plot(
    list(simset=simset), 
    outcomes=outcomes, 
    facet.by=facet.by, 
    summary.type=summary.type
  )
  
  print("\nExamining plot.data structure:")
  print("Class of plot.data:")
  print(class(plot.data))
  print("\nNames/components of plot.data:")
  print(names(plot.data))
  
  # Look at first few rows if it's a data frame
  if(is.data.frame(plot.data)) {
    print("\nFirst few rows of plot.data:")
    print(head(plot.data))
    print("\nColumn classes:")
    print(sapply(plot.data, class))
  }
  
  # If it's a list, examine top-level components
  if(is.list(plot.data) && !is.data.frame(plot.data)) {
    print("\nExamining each top-level component:")
    for(name in names(plot.data)) {
      print(paste("\nComponent:", name))
      print(paste("Class:", class(plot.data[[name]])))
      print(paste("Length/Dim:", 
                  if(is.null(dim(plot.data[[name]]))) 
                    length(plot.data[[name]]) 
                  else 
                    paste(dim(plot.data[[name]]), collapse="x")))
    }
  }
  
  print("Plot data prepared successfully")
  return(list(plot=plot.data))
}