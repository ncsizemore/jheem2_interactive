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
  print("\n=== Starting do.prepare.plot.and.table ===")
  print(paste("Type:", type))
  
  # Log input state
  print("Input settings:")
  str(input)
  print("Intervention settings:")
  str(intervention.settings)
  
  result <- prepare.plot.and.table(
    session = session,
    main.settings = get.main.settings(input, type),
    control.settings = get.control.settings(input, type),
    intervention.settings = intervention.settings
  )
  
  print("do.prepare.plot.and.table result structure:")
  str(result)
  return(result)
}

prepare.plot.and.table <- function(session,
                                   main.settings,
                                   control.settings,
                                   intervention.settings)
{
  tryCatch({
    print("\n=== Starting prepare.plot.and.table ===")
    print("Main settings:")
    str(main.settings)
    print("Control settings:")
    str(control.settings)
    print("Intervention settings:")
    str(intervention.settings)
    
    # Check if sim file exists
    sim_file <- 'simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata'
    if (!file.exists(sim_file)) {
      stop(paste("Simulation file not found:", sim_file))
    }
    
    print("Loading simulation data...")
    simset = get(load(sim_file))
    print("Simulation data class:")
    print(class(simset))
    print("Available outcomes:")
    print(simset$outcomes)
    
    print("\nCalling prepare.simulations.plot.and.table with settings:")
    print(paste("- outcomes:", paste(control.settings$outcomes, collapse=", ")))
    print(paste("- facet.by:", if(is.null(control.settings$facet.by)) "NULL" else paste(control.settings$facet.by, collapse=", ")))
    print(paste("- summary.type:", control.settings$summary.type))
    
    plot.results = prepare.simulations.plot.and.table(
      simset = simset,
      outcomes = control.settings$outcomes,
      facet.by = control.settings$facet.by,
      summary.type = control.settings$summary.type
    )
    
    print("\nprepare.plot.and.table output structure before adding settings:")
    str(plot.results)
    
    #-- Store Settings --#
    plot.results$main.settings = main.settings
    plot.results$control.settings = control.settings
    plot.results$int.settings = intervention.settings
    
    print("\nFinal prepare.plot.and.table output structure:")
    str(plot.results)
    
    return(plot.results)
  },
  error = function(e){
    print("\nError in prepare.plot.and.table!")
    print("Error details:")
    print(conditionMessage(e))
    print("Stack trace:")
    print(sys.calls())
    return(NULL)
  })
}

prepare.simulations.plot.and.table <- function(simset,
                                               outcomes,
                                               facet.by,
                                               summary.type)
{
  print("\n=== Starting prepare.simulations.plot.and.table ===")
  print("Input parameters:")
  print(paste("- simset class:", paste(class(simset), collapse=", ")))
  print(paste("- outcomes:", paste(outcomes, collapse=", ")))
  print(paste("- facet.by:", if(is.null(facet.by)) "NULL" else paste(facet.by, collapse=", ")))
  print(paste("- summary.type:", summary.type))
  
  # Right now, the simset doesn't have a name
  print("\nCalling prepare.plot...")
  plot.data = prepare.plot(
    list(simset=simset), 
    outcomes=outcomes, 
    facet.by=facet.by, 
    summary.type=summary.type
  )
  
  print("\nPrepare.plot output structure:")
  str(plot.data)
  
  result <- list(plot=plot.data)
  print("\nFinal prepare.simulations.plot.and.table output:")
  str(result)
  
  return(result)
}