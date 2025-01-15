# plotting/simplot/prepare_plot.R

#' Prepare plot data for simulation visualization
#' @param ... One or more simulation set objects or lists containing only simulation set objects
#' @param outcomes Character vector of simulation outcomes to plot
#' @param corresponding.data.outcomes Corresponding real-world data outcomes
#' @param split.by Dimension to split by (at most one)
#' @param facet.by Dimensions to facet by (any number, cannot include split.by)
#' @param dimension.values List of dimension values
#' @param plot.which What to plot ('both', 'sim.only', 'data.only')
#' @param summary.type Type of summary ('individual.simulation', 'mean.and.interval', 'median.and.interval')
#' @param plot.year.lag.ratio Whether to plot year lag ratio
#' @param data.manager Data manager for real-world data
#' @param debug Debug flag
#' @return List containing prepared plot data
prepare_plot <- function(...,
                         outcomes = NULL,
                         corresponding.data.outcomes = NULL,
                         split.by = NULL,
                         facet.by = NULL,
                         dimension.values = list(),
                         plot.which = c('both', 'sim.only', 'data.only')[1],
                         summary.type = c('individual.simulation', 'mean.and.interval', 'median.and.interval')[1],
                         plot.year.lag.ratio = F,
                         data.manager = get.default.data.manager(),
                         debug = F) {
    # -- VALIDATION -- #
    if (debug) browser()
    error.prefix = "Cannot generate simplot: "
    
    # Validate data manager
    if (!R6::is.R6(data.manager) || !is(data.manager, 'jheem.data.manager'))
        stop("'data.manager' must be an R6 object with class 'jheem.data.manager'")
    
    # Validate split.by
    if (!is.null(split.by) && (!is.character(split.by) || length(split.by) > 1 || is.na(split.by)))
        stop(paste0(error.prefix, "'split.by' must be NULL or a length one, non-NA character vector"))
    
    # Validate facet.by
    if (!is.null(facet.by) && (!is.character(facet.by) || length(facet.by) < 1 || any(is.na(facet.by)) || any(duplicated(facet.by))))
        stop(paste0(error.prefix, "'facet.by' must be NULL or a character vector with at least one element and no NAs or duplicates"))
    
    if (!is.null(split.by) && split.by %in% facet.by)
        stop(paste0(error.prefix, "'facet.by' must not contain the dimension in 'split.by'"))
    
    if (!is.null(split.by) && split.by == 'year')
        stop(paste0(error.prefix, "'split.by' cannot equal 'year'"))
    
    if (!is.null(facet.by) && 'year' %in% facet.by)
        stop(paste0(error.prefix, "'facet.by' cannot contain 'year'"))
    
    if (!(identical(plot.which, 'sim.only') || identical(plot.which, 'data.only') || identical(plot.which, 'both')))
        stop(paste0(error.prefix, "'plot.which' must be one of 'sim.only', 'data.only', or 'both'"))
    
    if (!(identical(summary.type, 'individual.simulation') || identical(summary.type, 'mean.and.interval') || identical(summary.type, 'median.and.interval')))
        stop(paste0(error.prefix, "'summary.type' must be one of 'individual.simulation', 'mean.and.interval', or 'median.and.interval'"))
    
    if (!identical(plot.year.lag.ratio, T) && !identical(plot.year.lag.ratio, F))
        stop(paste0(error.prefix, "'plot.year.lag.ratio' must be either T or F"))
    
    #-- STEP 1: PRE-PROCESSING --#
    # Get a list out of ... where each element is one simset (or sim for now)
    
    simset.args = list(...) # will later be SIMSETS
    
    outcomes.found.in.simset.args = F
    # each element of 'sim.list' should be either a sim or list containing only sims.
    for (element in simset.args) {
        if (!R6::is.R6(element) || !is(element, 'jheem.simulation.set')) {
            if (is.list(element)) {
                if (any(sapply(element, function(sub.element) {!R6::is.R6(sub.element) || !is(sub.element, 'jheem.simulation.set')}))) {
                    stop(paste0(error.prefix, "arguments supplied in '...' must either be jheem.simulation.set objects or lists containing only jheem.simulation.set objects"))
                }
            } else if (is.null(outcomes) && is.character(element)) {
                outcomes = element
                outcomes.found.in.simset.args = T
            }
            else
                stop(paste0(error.prefix, "arguments supplied in '...' must either be jheem.simulation.set objects or lists containing only jheem.simulation.set objects"))
        }
    }
    
    if (!is.character(outcomes) || is.null(outcomes) || any(is.na(outcomes)) || any(duplicated(outcomes))) {
        if (outcomes.found.in.simset.args)
            stop(paste0(error.prefix, "'outcomes' found as unnamed argument in '...' must be a character vector with no NAs or duplicates"))
        else
            stop(paste0(error.prefix, "'outcomes' must be a character vector with no NAs or duplicates"))
    }
    
    if (outcomes.found.in.simset.args) {
        if (length(simset.args) < 2)
            stop(paste0(error.prefix, "one or more jheem.simulation.set objects or lists containing only jheem.simulation.set objects must be supplied"))
        else
            simset.list = simset.args[1:(length(simset.args)-1)]
    }
    else {
        if (length(simset.args) < 1)
            stop(paste0(error.prefix, "one or more jheem.simulation.set objects or lists containing only jheem.simulation.set objects must be supplied"))
        else
            simset.list = simset.args
    }
    
    # if *plot.year.lag.ratio* is true, we can have only one outcome
    if (plot.year.lag.ratio && length(outcomes)>1)
        stop(paste0(error.prefix, "only one outcome can be used with 'plot.year.lag.ratio'"))
    
    # Now simset.list contains only simsets and lists containing only simsets. It needs to be just a single-level list of simsets now
    simset.list = unlist(simset.list, recursive = F)
    
    # - make sure they are all the same version and the location
    if (length(unique(sapply(simset.list, function(simset) {simset$version}))) > 1)
        stop(paste0(error.prefix, "all simulation sets must have the same version"))
    if (length(unique(sapply(simset.list, function(simset) {simset$location}))) > 1)
        stop(paste0(error.prefix, "all simulation sets must have the same location"))
    
    # Check outcomes
    # - make sure each outcome is present in sim$outcomes for at least one sim/simset
    if (any(sapply(outcomes, function(outcome) {!any(sapply(simset.list, function(simset) {outcome %in% simset$outcomes}))})))
        stop(paste0("There weren't any simulation sets for one or more outcomes. Should this be an error?"))
    
    # Get the real-world outcome names
    # - eventually we're going to want to pull this from info about the likelihood if the sim notes which likelihood was used on it
    # - what we'll do now will be the back-up to above
    #   sim$outcome.metadata[[outcome]]$corresponding.observed.outcome
    # sims do not all have each outcome because of sub-versions
    
    # likelihoods need to share their outcome for sim and data, and think about what joint likelihoods. One simulation has one (usually joint) likelihood (instructions)
    # browser()
    outcomes.for.data = sapply(outcomes, function(outcome) {
        if (outcome %in% names(corresponding.data.outcomes))
            return(corresponding.data.outcomes[[outcome]])
        corresponding.observed.outcome = NULL
        i = 1
        while (i <= length(simset.list)) {
            if (outcome %in% names(simset.list[[i]]$outcome.metadata)) {
                corresponding.observed.outcome = simset.list[[i]]$outcome.metadata[[outcome]]$corresponding.observed.outcome
                break
            } else i = i + 1
        }
        corresponding.observed.outcome
    })
    
    outcome.ontologies = lapply(outcomes, function(outcome) {
        outcome.ontology = NULL
        i = 1
        while (i <= length(simset.list)) {
            if (outcome %in% names(simset.list[[i]]$outcome.ontologies)) {
                outcome.ontology = simset.list[[i]]$outcome.ontologies[[outcome]]
                break
            } else i = i + 1
        }
        if (is.null(outcome.ontology))
            stop(paste0("No outcome ontology found for outcome '", outcome, "'")) # Shouldn't happen
        outcome.ontology
    })
    
    outcome.locations = lapply(outcomes, function(outcome) {
        locations.this.outcome = unique(unlist(lapply(simset.list, function(simset) {
            simset$outcome.location.mapping$get.observed.locations(outcome, simset$location)
        })))
    })
    names(outcome.locations) = outcomes.for.data
    # browser()
    
    #-- STEP 2: MAKE A DATA FRAME WITH ALL THE REAL-WORLD DATA --#
    
    outcome.mappings = list() # note: not all outcomes will have corresponding data outcomes
    # browser()
    df.truth = NULL
    for (i in seq_along(outcomes.for.data))
    {
        if (plot.which != 'sim.only' && !is.null(outcomes.for.data[[i]]))
        {
            outcome.data = tryCatch(
                {
                    result = data.manager$pull(outcome = outcomes.for.data[[i]],
                                               dimension.values = c(dimension.values, list(location = outcome.locations[[i]])),
                                               keep.dimensions = c('year', 'location', facet.by, split.by), #'year' can never be in facet.by
                                               target.ontology = outcome.ontologies[[i]],
                                               allow.mapping.from.target.ontology = T,
                                               na.rm=T,
                                               debug=F)
                },
                error = function(e) {
                    NULL
                }
            )
            outcome.mappings = c(outcome.mappings, list(attr(outcome.data, 'mapping')))
            if (!is.null(outcome.data)) {
                
                # If we have multiple outcomes that may map differently (for example, with years), the factor levels unavoidably determined by the first outcome for reshape2::melt may not be valid for subsequent outcomes
                one.df.outcome = reshape2::melt(outcome.data, na.rm = T)
                one.df.outcome = as.data.frame(lapply(one.df.outcome, function(col) {
                    if (is.factor(col)) as.character(col)
                    else col
                }))
                
                corresponding.outcome = names(outcomes.for.data)[[i]]
                one.df.outcome['outcome'] = corresponding.outcome
                df.truth = rbind(df.truth, one.df.outcome)
            }
        }
        else
        {
            outcome.mappings = c(outcome.mappings, list(NULL))
        }
    }
    if (!is.null(df.truth)) {
        # make whatever column corresponds to split by actually be called "stratum" and same for facet.by.
        if (!is.null(split.by)) names(df.truth)[names(df.truth)==split.by] = "stratum"
        if (!is.null(facet.by)) names(df.truth)[names(df.truth)==facet.by] = "facet.by"
        
        # if there is no 'stratum' because no split, then we should fill it with ""
        if (!('stratum' %in% names(df.truth))) df.truth['stratum'] = rep('', nrow(df.truth))
        
        # sort the split.by column alphabetically so that when we assign colors, it will be the same for sim.
        if (!is.null(split.by))
            df.truth = df.truth[order(df.truth$stratum),]
    }
    names(outcome.mappings) = outcomes
    
    df.sim = NULL
    if (plot.which != 'data.only') {
        for (outcome in outcomes) {
            
            keep.dimensions = c('year', facet.by, split.by)
            for (i in seq_along(simset.list)) {
                
                simset = simset.list[[i]]
                if (!is.null(outcome.mappings[[outcome]])) mapping.this.outcome = outcome.mappings[[outcome]]
                else mapping.this.outcome = NULL
                # browser()
                simset.data.this.outcome = simset$get(outcomes = outcome,
                                                      dimension.values = dimension.values,
                                                      keep.dimensions = keep.dimensions,
                                                      drop.single.outcome.dimension = T,
                                                      mapping=mapping.this.outcome,
                                                      summary.type = summary.type)
                
                if (is.null(simset.data.this.outcome)) next
                
                # If we have multiple outcomes that may map differently (for example, with years), the factor levels unavoidably determined by the first outcome for reshape2::melt may not be valid for subsequent outcomes
                one.df.sim.this.outcome = reshape2::melt(simset.data.this.outcome, na.rm = T)
                one.df.sim.this.outcome = as.data.frame(lapply(one.df.sim.this.outcome, function(col) {
                    if (is.factor(col)) as.character(col)
                    else col
                }))
                
                one.df.sim.this.outcome['simset'] = i
                one.df.sim.this.outcome['outcome'] = outcome
                one.df.sim.this.outcome['linewidth'] = 1/sqrt(simset$n.sim) # have style manager create this later?
                one.df.sim.this.outcome['alpha'] = one.df.sim.this.outcome['linewidth'] # same comment as above; USED to be 20 * this
                
                df.sim = rbind(df.sim, one.df.sim.this.outcome)
            }
        }
        
        # Pivot wider to convert column "metric" to columns "value.mean", "value.lower", "value.upper" or such
        if (summary.type != 'individual.simulation') {
            df.sim = reshape(df.sim, direction='wide', idvar=names(df.sim)[!(names(df.sim) %in% c('metric', 'value'))], timevar='metric')
            if (!is.null(df.sim[['value.mean']])) df.sim$value = df.sim$value.mean
            if (!is.null(df.sim[['value.median']])) df.sim$value = df.sim$value.median
        }
        
        
        
        # make whatever column corresponds to split by actually be called "stratum" and same for facet.by.
        if (!is.null(split.by)) df.sim["stratum"] = df.sim[split.by]
        if (!is.null(facet.by)) df.sim["facet.by"] = df.sim[facet.by]
        
        # if we don't have a 'stratum' col because no split, make an empty one
        if (!('stratum' %in% names(df.sim))) df.sim['stratum'] = rep('', nrow(df.sim))
        
        df.sim$simset = factor(df.sim$simset)
        df.sim$sim = factor(df.sim$sim)
        df.sim$groupid = paste0(df.sim$outcome, '_', df.sim$simset, '_', df.sim$sim, '_', df.sim$stratum)
        
        # sort split by alphabetically to line it up with df.truth when colors are picked
        if (!is.null(split.by))
            df.sim = df.sim[order(df.sim$stratum),]
    }
    
    ## YEAR LAG RATIO
    if (plot.year.lag.ratio) {
        ## We will take log of values, then difference, then exponentiate result
        if (!is.null(df.truth)) {
            df.truth$value = log(df.truth$value)
            if (!is.null(split.by)) {
                if (!is.null(facet.by))
                    df.truth[['stratum']] = do.call(paste, list(df.truth$stratum, df.truth$facet.by, sep="__"))
            }
            else if (!is.null(facet.by))
                df.truth[['stratum']] = df.truth$facet.by
            else df.truth[['stratum']] = rep(0, nrow(df.truth))
            truth.lag.indices = generate_lag_matrix_indices(as.integer(as.factor(df.truth$year)),
                                                            as.integer(as.factor(df.truth$location)),
                                                            as.integer(as.factor(df.truth$stratum)),
                                                            as.integer(as.factor(df.truth$source)),
                                                            nrow(df.truth))
            truth.n.lag.pairs = length(truth.lag.indices)/2
            
            truth.lag.values = apply_lag_to_vector(df.truth$value, truth.lag.indices, rep(0, truth.n.lag.pairs), truth.n.lag.pairs)
            truth.rows.to.keep = truth.lag.indices[rep(c(T,F), truth.n.lag.pairs/2)]
            df.truth = df.truth[truth.rows.to.keep,]
            df.truth$value = exp(truth.lag.values)
            
            # Remove NAs or Infs generated in this process
            df.truth = df.truth[!is.na(df.truth$value) & !is.infinite(df.truth$value),]
        }
        if (!is.null(df.sim)) {
            df.sim$value = log(df.sim$value)
            if (!is.null(split.by)) {
                if (!is.null(facet.by))
                    df.sim[['stratum']] = do.call(paste, list(df.sim$stratum, df.sim$facet.by, sep="__"))
            }
            else if (!is.null(facet.by))
                df.sim[['stratum']] = df.sim$facet.by
            else df.sim[['stratum']] = rep(0, nrow(df.sim))
            # browser()
            sim.lag.indices = generate_lag_matrix_indices(as.integer(as.factor(df.sim$year)),
                                                          as.integer(as.factor(df.sim$sim)),
                                                          as.integer(as.factor(df.sim$stratum)),
                                                          as.integer(as.factor(df.sim$simset)),
                                                          nrow(df.sim))
            sim.n.lag.pairs = length(sim.lag.indices)/2
            
            sim.lag.values = apply_lag_to_vector(df.sim$value, sim.lag.indices, rep(0, sim.n.lag.pairs), sim.n.lag.pairs)
            sim.rows.to.keep = sim.lag.indices[rep(c(T,F), sim.n.lag.pairs/2)]
            df.sim = df.sim[sim.rows.to.keep,]
            df.sim$value = exp(sim.lag.values)
            
            # Remove NAs or Infs generated in this process
            df.sim = df.sim[!is.na(df.sim$value) & !is.infinite(df.sim$value),]
        }
    }
    
    y.label = paste0(sapply(outcomes, function(outcome) {simset.list[[1]][['outcome.metadata']][[outcome]][['units']]}), collapse='/')
    
    # Return prepared data
    return(list(df.sim = df.sim, df.truth = df.truth, details = list(y.label = y.label)))
}