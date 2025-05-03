# src/utils/simplot_local_mods.R
# Contains local modifications of jheem2::simplot and its helpers
# specifically for ggplotly rendering in this application.

library(ggplot2)
library(reshape2)
library(ggnewscale) # Needed for execute_simplot_local modifications
library(scales) # Needed for execute_simplot_local modifications

# Renamed local version of jheem2::simplot
simplot_local <- function(...,
                          outcomes = NULL,
                          corresponding.data.outcomes = NULL,
                          split.by = NULL,
                          facet.by = NULL,
                          dimension.values = list(),
                          target.ontology = NULL,
                          plot.which = c("sim.and.data", "sim.only")[1],
                          summary.type = c("individual.simulation", "mean.and.interval", "median.and.interval")[1],
                          plot.year.lag.ratio = F,
                          title = "location",
                          n.facet.rows = NULL,
                          append.url = F,
                          data.manager = get.default.data.manager(),
                          style.manager = get.default.style.manager(),
                          show.data.pull.error = F,
                          debug = F) {
    # Calls local validation helper
    plot.data <- plot_data_validation_local(
        list(...),
        match.call(expand.dots = F)$...,
        outcomes,
        corresponding.data.outcomes,
        plot.which,
        summary.type
    )

    # These values are possibly modified by the plot.data.validation call, so
    # they need to be extracted from the returned list.
    simset.list <- plot.data$simset.list
    outcomes <- plot.data$outcomes

    # Calls local prepare helper
    prepared.plot.data <- prepare_plot_local(simset.list,
        outcomes = outcomes,
        locations = NULL,
        corresponding.data.outcomes = corresponding.data.outcomes,
        split.by = split.by,
        facet.by = facet.by,
        dimension.values = dimension.values,
        target.ontology = target.ontology,
        plot.which = plot.which,
        summary.type = summary.type,
        plot.year.lag.ratio = plot.year.lag.ratio,
        title = title,
        append.url = append.url,
        data.manager = data.manager,
        style.manager = style.manager,
        show.data.pull.error = show.data.pull.error,
        debug = debug
    )

    # Calls local execute helper (where modifications are made)
    execute_simplot_local(prepared.plot.data,
        outcomes = outcomes,
        split.by = split.by,
        facet.by = facet.by,
        plot.which = plot.which,
        summary.type = summary.type,
        plot.year.lag.ratio = plot.year.lag.ratio,
        n.facet.rows = n.facet.rows,
        style.manager = style.manager,
        debug = debug
    )
}

# Renamed local version of jheem2::plot.data.validation (no functional changes needed here)
plot_data_validation_local <- function(simset.args,
                                       deparsed.substituted.args.simset.args,
                                       outcomes,
                                       corresponding.data.outcomes,
                                       plot.which,
                                       summary.type) {
    rv <- list()

    error.prefix <- "Cannot generate simplot_local: " # Updated prefix

    if (!(identical(plot.which, "sim.and.data") || identical(plot.which, "sim.only"))) {
        stop(paste0(error.prefix, "'plot.which' must be either 'sim.and.data' or 'sim.only'"))
    }

    if (!(identical(summary.type, "individual.simulation") || identical(summary.type, "mean.and.interval") || identical(summary.type, "median.and.interval"))) {
        stop(paste0(error.prefix, "'summary.type' must be one of 'individual.simulation', 'mean.and.interval', or 'median.and.interval'"))
    }

    # *corresponding.data.outcomes' is NULL or a vector with outcomes as names
    if (!is.null(corresponding.data.outcomes) && (!is.character(corresponding.data.outcomes) || any(is.na(corresponding.data.outcomes)) || is.null(names(corresponding.data.outcomes)) || !all(names(corresponding.data.outcomes) %in% outcomes))) {
        stop(paste0(error.prefix, "'corresponding.data.outcomes' must be NULL or a character vector with outcomes as names and all of those outcomes specified in either the 'outcomes' argument or in '...'"))
    }

    # each element of 'sim.list' should be a simset
    arg.is.simset <- sapply(simset.args, function(element) {
        if (!R6::is.R6(element) || !is(element, "jheem.simulation.set")) {
            if (is.character(element)) {
                return(FALSE)
            } else {
                stop(paste0(error.prefix, "arguments supplied in '...' must be jheem.simulation.set objects and at most one character vector of outcomes"))
            }
        }
        return(TRUE)
    })

    # Pull out outcomes, which may be at most one element of the ...
    rv$outcomes <- outcomes
    if (sum(!arg.is.simset) > 0) {
        if (!is.null(outcomes)) {
            stop(paste0(error.prefix, "outcomes must be specified either in '...' arguments or in the 'outcomes' argument, but not both"))
        }
        if (sum(!arg.is.simset) > 1) {
            stop(paste0(error.prefix, "at most one character vector of outcomes may be suppied in '...' arguments as an alternative to the 'outcomes' argument"))
        }
        rv$outcomes <- unlist(simset.args[!arg.is.simset])
    }
    if (!is.character(rv$outcomes) || is.null(rv$outcomes) || any(is.na(rv$outcomes)) || any(duplicated(rv$outcomes))) {
        if (sum(!arg.is.simset) > 0) {
            stop(paste0(error.prefix, "'outcomes' found as unnamed argument in '...' must be a character vector with no NAs or duplicates"))
        } else {
            stop(paste0(error.prefix, "'outcomes' must be a character vector with no NAs or duplicates"))
        }
    }

    if (sum(arg.is.simset) < 1) {
        stop(paste0(error.prefix, "one or more jheem.simulation.set objects must be supplied"))
    }
    # browser()
    # Add names to simsets
    rv$simset.list <- setNames(simset.args[arg.is.simset], deparsed.substituted.args.simset.args[arg.is.simset])
    if (is.null(names(simset.args))) {
        simset.explicitly.named <- rep(F, sum(arg.is.simset))
    } else {
        simset.explicitly.named <- sapply(names(simset.args[arg.is.simset]), function(name) {
            nchar(name) > 0
        })
    }
    names(rv$simset.list)[simset.explicitly.named] <- names(simset.args)[simset.explicitly.named]

    # - make sure they are all the same version and the location
    if (length(unique(sapply(rv$simset.list, function(simset) {
        simset$version
    }))) > 1) {
        stop(paste0(error.prefix, "all simulation sets must have the same version"))
    }
    if (length(unique(sapply(rv$simset.list, function(simset) {
        simset$location
    }))) > 1) {
        stop(paste0(error.prefix, "all simulation sets must have the same location"))
    }

    # Check outcomes
    # - make sure each outcome is present in sim$outcomes for at least one sim/simset
    if (any(sapply(rv$outcomes, function(outcome) {
        !any(sapply(rv$simset.list, function(simset) {
            outcome %in% simset$outcomes
        }))
    }))) {
        stop(paste0("There weren't any simulation sets for one or more outcomes. Should this be an error?"))
    }

    return(rv)
}


# Renamed local version of jheem2::prepare.plot (no functional changes needed here)
prepare_plot_local <- function(simset.list = NULL,
                               outcomes = NULL,
                               locations = NULL,
                               corresponding.data.outcomes = NULL,
                               split.by = NULL,
                               facet.by = NULL,
                               dimension.values = list(),
                               target.ontology = NULL,
                               plot.which = c("sim.and.data", "sim.only", "data.only")[1],
                               summary.type = c("individual.simulation", "mean.and.interval", "median.and.interval")[1],
                               plot.year.lag.ratio = F,
                               title = "location",
                               append.url = F,
                               data.manager = get.default.data.manager(),
                               style.manager = get.default.style.manager(),
                               show.data.pull.error = F,
                               debug = F) {
    #-- VALIDATION ----
    if (debug) browser()
    error.prefix <- "Cannot generate simplot_local: " # Updated prefix

    if (!R6::is.R6(data.manager) || !is(data.manager, "jheem.data.manager")) {
        stop("'data.manager' must be an R6 object with class 'jheem.data.manager'")
    }

    # *split.by* is NULL or a single, non-NA character vector
    if (!is.null(split.by) && (!is.character(split.by) || length(split.by) > 1 || is.na(split.by))) {
        stop(paste0(error.prefix, "'split.by' must be NULL or a length one, non-NA character vector"))
    }

    # *facet.by* is NULL or a character vector of length > 0 with no NAs or duplicates
    if (!is.null(facet.by) && (!is.character(facet.by) || length(facet.by) < 1 || any(is.na(facet.by)) || any(duplicated(facet.by)))) {
        stop(paste0(error.prefix, "'facet.by' must be NULL or a character vector with at least one element and no NAs or duplicates"))
    }

    if (!is.null(split.by) && split.by %in% facet.by) {
        stop(paste0(error.prefix, "'facet.by' must not contain the dimension in 'split.by'"))
    }

    if (!is.null(split.by) && split.by == "year") {
        stop(paste0(error.prefix, "'split.by' cannot equal 'year'"))
    }

    if (!is.null(facet.by) && "year" %in% facet.by) {
        stop(paste0(error.prefix, "'facet.by' cannot contain 'year'"))
    }

    if (!is.null(target.ontology) &&
        !is.ontology(target.ontology) &&
        !(is.list(target.ontology) && all(sapply(target.ontology, function(x) {
            is.ontology((x))
        })) && !is.null(names(target.ontology)))) {
        stop(paste0(error.prefix, "'target.ontology' must be NULL, an ontology, or a list of ontologies with outcomes as names"))
    }

    # Must supply a target ontology if using simplot.data.only, because otherwise multiple outcomes won't be alignable...?

    if (!identical(plot.year.lag.ratio, T) && !identical(plot.year.lag.ratio, F)) {
        stop(paste0(error.prefix, "'plot.year.lag.ratio' must be either T or F"))
    }

    # if *plot.year.lag.ratio* is true, we can have only one outcome
    if (plot.year.lag.ratio && length(outcomes) > 1) {
        stop(paste0(error.prefix, "only one outcome can be used with 'plot.year.lag.ratio'"))
    }

    if (!is.null(title) && (!is.character(title) || length(title) != 1 || is.na(title))) {
        stop(paste0(error.prefix, "'title' must be NULL or a single, non-NA character value"))
    }

    if (!identical(append.url, T) && !identical(append.url, F)) {
        stop(paste0(error.prefix, "'append.url' must be either T or F"))
    }

    if (!identical(show.data.pull.error, T) && !identical(show.data.pull.error, F)) {
        stop(paste0(error.prefix, "'show.data.pull.error' must be either T or F"))
    }

    # Get the real-world outcome names
    # - eventually we're going to want to pull this from info about the likelihood if the sim notes which likelihood was used on it
    # - what we'll do now will be the back-up to above
    #   sim$outcome.metadata[[outcome]]$corresponding.observed.outcome
    # sims do not all have each outcome because of sub-versions


    #-- GET OUTCOME METADATA ----
    if (plot.which == "data.only") {
        outcome.metadata.list <- lapply(outcomes, function(outcome) {
            data.manager$outcome.info[[outcome]]$metadata
        })
    } else {
        outcome.metadata.list <- lapply(outcomes, function(outcome) {
            i <- 1
            while (i <= length(simset.list)) {
                if (outcome %in% names(simset.list[[i]]$outcome.metadata)) {
                    return(simset.list[[i]]$outcome.metadata[[outcome]])
                } else {
                    i <- i + 1
                }
            }
            stop(paste0(error.prefix, "Consult Andrew: this simplot bug shouldn't happen"))
        })
    }
    names(outcome.metadata.list) <- outcomes

    # likelihoods need to share their outcome for sim and data, and think about what joint likelihoods. One simulation has one (usually joint) likelihood (instructions)
    if (plot.which == "data.only") {
        outcomes.for.data <- setNames(outcomes, outcomes)
    } else {
        outcomes.for.data <- sapply(outcomes, function(outcome) {
            if (outcome %in% names(corresponding.data.outcomes)) {
                return(corresponding.data.outcomes[[outcome]])
            }
            corresponding.observed.outcome <- NULL
            i <- 1
            while (i <= length(simset.list)) {
                if (outcome %in% names(simset.list[[i]]$outcome.metadata)) {
                    corresponding.observed.outcome <- simset.list[[i]]$outcome.metadata[[outcome]]$corresponding.observed.outcome
                    break
                } else {
                    i <- i + 1
                }
            }
            corresponding.observed.outcome
        })
    }

    if (plot.which == "data.only") {
        outcome.ontologies <- NULL
    } else {
        outcome.ontologies <- lapply(outcomes, function(outcome) {
            # Restore original logic: Always try to find ontology from simset.list first
            outcome.ontology <- NULL # Initialize
            i <- 1
            while (i <= length(simset.list)) {
                if (outcome %in% names(simset.list[[i]]$outcome.ontologies)) {
                    outcome.ontology <- simset.list[[i]]$outcome.ontologies[[outcome]]
                    break
                } else {
                    i <- i + 1
                }
            }
            # Check *after* the loop if an ontology was found
            if (is.null(outcome.ontology)) {
                stop(paste0("No outcome ontology found for outcome '", outcome, "'"))
            } # Shouldn't happen
            outcome.ontology
        })
        names(outcome.ontologies) <- outcomes # Name the list
    }


    if (plot.which == "data.only") {
        outcome.locations <- locations
    } else {
        outcome.locations <- lapply(outcomes, function(outcome) {
            locations.this.outcome <- unique(unlist(lapply(simset.list, function(simset) {
                simset$outcome.location.mapping$get.observed.locations(outcome, simset$location)
            })))
        })
        # Name the list using the *data* outcomes they correspond to
        names(outcome.locations) <- outcomes.for.data
    }


    # Get sim labels (like "MSM/PWID" instead of "msm_idu")
    if (plot.which != "data.only") {
        sim.labels.list <- lapply(simset.list, function(simset) {
            simset$metadata$labels
        })
    } else {
        sim.labels.list <- NULL
    }


    #-- MAKE A DATA FRAME WITH ALL THE REAL-WORLD DATA ----

    outcome.mappings <- list() # note: not all outcomes will have corresponding data outcomes
    source.metadata.list <- list()
    if (append.url) append.attributes <- "url" else append.attributes <- NULL

    df.truth <- NULL
    for (i in seq_along(outcomes.for.data))
    {
        current_data_outcome <- outcomes.for.data[[i]]
        current_sim_outcome <- names(outcomes.for.data)[[i]] # The sim outcome corresponding to this data outcome

        if (plot.which != "sim.only" && !is.null(current_data_outcome)) {
            # Get locations specific to this data outcome
            locations_for_pull <- outcome.locations[[current_data_outcome]]
            if (is.null(locations_for_pull)) next # Skip if no locations mapped

            outcome.data <- tryCatch(
                {
                    # browser()
                    # Revert to original pull logic structure
                    if (!is.null(target.ontology) && !is.list(target.ontology)) {
                        result <- data.manager$pull(
                            outcome = current_data_outcome, # Use current_data_outcome
                            dimension.values = c(dimension.values, list(location = locations_for_pull)), # Use locations_for_pull
                            keep.dimensions = c("year", "location", facet.by, split.by), #' year' can never be in facet.by
                            target.ontology = target.ontology,
                            allow.mapping.from.target.ontology = F,
                            append.attributes = append.attributes,
                            na.rm = T,
                            debug = F
                        )
                    } else if (is.list(target.ontology) && current_data_outcome %in% names(target.ontology)) { # Use current_data_outcome
                        result <- data.manager$pull(
                            outcome = current_data_outcome, # Use current_data_outcome
                            dimension.values = c(dimension.values, list(location = locations_for_pull)), # Use locations_for_pull
                            keep.dimensions = c("year", "location", facet.by, split.by), #' year' can never be in facet.by
                            target.ontology = target.ontology[[current_data_outcome]], # Use current_data_outcome
                            allow.mapping.from.target.ontology = F,
                            append.attributes = append.attributes,
                            na.rm = T,
                            debug = F
                        )
                    } else if (plot.which == "sim.and.data") {
                        result <- data.manager$pull(
                            outcome = current_data_outcome, # Use current_data_outcome
                            dimension.values = c(dimension.values, list(location = locations_for_pull)), # Use locations_for_pull
                            keep.dimensions = c("year", "location", facet.by, split.by), #' year' can never be in facet.by
                            target.ontology = outcome.ontologies[[current_sim_outcome]], # Use current_sim_outcome
                            allow.mapping.from.target.ontology = T,
                            append.attributes = append.attributes,
                            na.rm = T,
                            debug = F
                        )
                    } else { # See if we really want this or not (Original comment)
                        result <- data.manager$pull(
                            outcome = current_data_outcome, # Use current_data_outcome
                            dimension.values = c(dimension.values, list(location = locations_for_pull)), # Use locations_for_pull
                            keep.dimensions = c("year", "location", facet.by, split.by), #' year' can never be in facet.by
                            target.ontology = NULL,
                            append.attributes = append.attributes,
                            na.rm = T,
                            debug = F
                        )
                    }
                    result # Explicitly return result
                },
                error = function(e) {
                    if (show.data.pull.error) {
                        stop(paste0(error.prefix, e))
                    } else {
                        NULL
                    } # Original simpler error handling
                }
            )

            # Store mapping attribute if it exists
            mapping_attr <- attr(outcome.data, "mapping")
            outcome.mappings[[current_sim_outcome]] <- mapping_attr # Store by sim outcome name

            if (!is.null(outcome.data) && nrow(outcome.data) > 0) {
                # If the scale is proportion, multiply data by 100 to match the "%" symbol the label will have
                if (data.manager$outcome.info[[current_data_outcome]]$metadata$display.as.percent) {
                    outcome.data <- outcome.data * 100
                }

                # Melt the data
                one.df.outcome <- reshape2::melt(outcome.data, na.rm = T, as.is = T)

                # Add URL if requested
                if (append.url && !is.null(attr(outcome.data, "url"))) {
                    url_data <- attr(outcome.data, "url")
                    # Ensure URL data aligns with outcome data before melting/binding
                    # This might require careful handling if dimensions don't match perfectly
                    # For simplicity, assuming direct melt works if dimensions align:
                    melted_urls <- reshape2::melt(url_data, na.rm = T, as.is = T)
                    # Align melted URLs with melted outcome data (this is complex if dimensions differ)
                    # A safer approach might involve joining based on dimension columns
                    # Placeholder: Assuming direct cbind works (requires perfect alignment)
                    if (nrow(one.df.outcome) == nrow(melted_urls)) {
                        one.df.outcome$url <- melted_urls$value
                    } else {
                        warning("URL data dimensions did not match outcome data for ", current_data_outcome)
                    }
                }

                # Check year ranges
                if (!any(sapply(one.df.outcome$year, is.year.range))) { # Assuming is.year.range exists
                    one.df.outcome$year <- as.numeric(one.df.outcome$year)
                } else if (plot.year.lag.ratio) {
                    stop(paste0(error.prefix, "cannot use 'plot.year.lag.ratio' when data is in year ranges"))
                }

                # Add source metadata
                if ("source" %in% names(one.df.outcome)) {
                    sources.this.outcome <- unique(one.df.outcome$source)
                    new_sources <- setdiff(sources.this.outcome, names(source.metadata.list))
                    if (length(new_sources) > 0) {
                        source.metadata.list[new_sources] <- data.manager$source.info[new_sources]
                    }
                } else {
                    one.df.outcome$source <- "Unknown" # Add source if missing
                    if (!("Unknown" %in% names(source.metadata.list))) {
                        source.metadata.list[["Unknown"]] <- list(name = "Unknown", url = NA) # Add basic unknown source info
                    }
                }


                # Add outcome identifiers
                one.df.outcome["outcome"] <- current_sim_outcome # Use the *simulation* outcome name
                one.df.outcome["outcome.display.name"] <- outcome.metadata.list[[current_sim_outcome]]$display.name
                df.truth <- rbind(df.truth, one.df.outcome)
            }
        } else {
            # Ensure mapping list has entry even if no data pulled/found
            outcome.mappings[[current_sim_outcome]] <- NULL
        }
    }

    if (!is.null(df.truth)) {
        # Rename split.by and facet.by columns
        if (!is.null(split.by) && split.by %in% names(df.truth)) names(df.truth)[names(df.truth) == split.by] <- "stratum"
        if (!is.null(facet.by)) {
            for (fb in facet.by) {
                if (fb %in% names(df.truth)) {
                    new_name <- paste0("facet.by", match(fb, facet.by))
                    names(df.truth)[names(df.truth) == fb] <- new_name
                }
            }
        }

        # Ensure 'stratum' column exists
        if (!("stratum" %in% names(df.truth))) df.truth["stratum"] <- ""

        # Sort by stratum for consistent coloring
        if ("stratum" %in% names(df.truth)) {
            df.truth <- df.truth[order(df.truth$stratum), ]
        }
    }
    # names(outcome.mappings) = outcomes # Already named by sim outcome

    #-- MAKE A DATA FRAME WITH THE SIMULATION DATA ----

    df.sim <- NULL
    if (plot.which != "data.only") {
        for (outcome in outcomes) {
            keep.dimensions <- unique(c("year", facet.by, split.by)) # Ensure year is kept, handle NULLs
            for (i in seq_along(simset.list)) {
                simset <- simset.list[[i]]
                # Get mapping for this specific sim outcome
                mapping.this.outcome <- outcome.mappings[[outcome]]

                # browser()
                simset.data.this.outcome <- simset$get(
                    outcomes = outcome,
                    dimension.values = dimension.values,
                    keep.dimensions = keep.dimensions,
                    drop.single.outcome.dimension = T,
                    mapping = mapping.this.outcome, # Use pre-calculated mapping
                    summary.type = summary.type
                )

                if (is.null(simset.data.this.outcome)) next

                # If the scale is proportion, multiply data by 100
                if (simset.list[[i]][["outcome.metadata"]][[outcome]]$display.as.percent) {
                    simset.data.this.outcome <- simset.data.this.outcome * 100
                }

                # Melt data
                one.df.sim.this.outcome <- reshape2::melt(simset.data.this.outcome, na.rm = T, as.is = T) # Added as.is=T

                # Convert factors to characters to avoid issues later
                # one.df.sim.this.outcome = as.data.frame(lapply(one.df.sim.this.outcome, function(col) {
                #     if (is.factor(col)) as.character(col)
                #     else col
                # }))

                one.df.sim.this.outcome["simset"] <- names(simset.list)[[i]]
                one.df.sim.this.outcome["outcome"] <- outcome
                # Calculate linewidth and alpha
                one.df.sim.this.outcome["linewidth"] <- 1 / (style.manager$linewidth.slope * log10(simset$n.sim) + 1)
                one.df.sim.this.outcome["alpha"] <- one.df.sim.this.outcome["linewidth"]

                # Add display name
                one.df.sim.this.outcome["outcome.display.name"] <- outcome.metadata.list[[outcome]]$display.name

                df.sim <- rbind(df.sim, one.df.sim.this.outcome)
            }
        }

        # Pivot wider if needed
        if (summary.type != "individual.simulation" && !is.null(df.sim) && nrow(df.sim) > 0) {
            if ("metric" %in% names(df.sim)) {
                # Ensure value column exists before pivoting
                if (!"value" %in% names(df.sim)) df.sim$value <- NA # Should not happen if melt worked

                # Identify id variables correctly
                id_vars <- names(df.sim)[!names(df.sim) %in% c("metric", "value")]
                # Check for duplicates before reshape
                dupe_check <- df.sim[, id_vars, drop = FALSE]
                if (any(duplicated(dupe_check))) {
                    warning("Duplicate combinations of ID variables found before reshaping simulation data. Check 'metric' column and dimensions.")
                    # Potentially add code here to handle duplicates if necessary
                }

                df.sim <- tryCatch(
                    {
                        reshape(df.sim, direction = "wide", idvar = id_vars, timevar = "metric")
                    },
                    error = function(e) {
                        warning(paste("Error reshaping simulation data:", conditionMessage(e)))
                        df.sim # Return original df.sim on error
                    }
                )

                # Rename pivoted columns if they exist and assign to 'value'
                if ("value.mean" %in% names(df.sim)) {
                    df.sim$value <- df.sim$value.mean
                } else if ("value.median" %in% names(df.sim)) {
                    df.sim$value <- df.sim$value.median
                }
                # Ensure value.lower and value.upper exist if needed for ribbons later
                if (!("value.lower" %in% names(df.sim))) df.sim$value.lower <- NA
                if (!("value.upper" %in% names(df.sim))) df.sim$value.upper <- NA
            } else {
                # Handle case where 'metric' column is missing
                if (!("value.lower" %in% names(df.sim))) df.sim$value.lower <- NA
                if (!("value.upper" %in% names(df.sim))) df.sim$value.upper <- NA
            }
        } else if (!is.null(df.sim) && nrow(df.sim) > 0) {
            # Ensure value.lower and value.upper exist even for individual sims, set to NA
            if (!("value.lower" %in% names(df.sim))) df.sim$value.lower <- NA
            if (!("value.upper" %in% names(df.sim))) df.sim$value.upper <- NA
        }


        if (!is.null(df.sim) && nrow(df.sim) > 0) {
            # Rename split.by and facet.by columns
            if (!is.null(split.by) && split.by %in% names(df.sim)) df.sim["stratum"] <- df.sim[[split.by]]
            if (!is.null(facet.by)) {
                for (fb in facet.by) {
                    if (fb %in% names(df.sim)) {
                        new_name <- paste0("facet.by", match(fb, facet.by))
                        df.sim[[new_name]] <- df.sim[[fb]] # Create new column
                    }
                }
            }

            # Ensure 'stratum' column exists
            if (!("stratum" %in% names(df.sim))) df.sim["stratum"] <- ""

            # Ensure 'sim' column exists before factoring
            if ("sim" %in% names(df.sim)) {
                df.sim$sim <- factor(df.sim$sim)
            } else {
                df.sim$sim <- 1 # Create a dummy 'sim' column
            }
            df.sim$simset <- factor(df.sim$simset)
            # Create groupid robustly
            df.sim$groupid <- interaction(df.sim$outcome, df.sim$simset, df.sim$sim, df.sim$stratum, drop = TRUE, sep = "_")


            # Sort by stratum
            if ("stratum" %in% names(df.sim)) {
                df.sim <- df.sim[order(df.sim$stratum), ]
            }
        }
    }


    #-- YEAR LAG RATIO ----
    if (plot.year.lag.ratio) {
        # (Keeping original year lag ratio code - assuming it works and functions exist)
        if (!is.null(df.truth)) {
            df.truth$value <- log(df.truth$value)
            temp_stratum_cols <- c(
                if (!is.null(split.by) && "stratum" %in% names(df.truth)) "stratum" else NULL,
                if (!is.null(facet.by)) paste0("facet.by", seq_along(facet.by)[facet.by %in% names(df.truth)]) else NULL
            )
            if (length(temp_stratum_cols) > 0) {
                df.truth[["temp_stratum_for_lag"]] <- apply(df.truth[, temp_stratum_cols, drop = FALSE], 1, paste, collapse = "__")
            } else {
                df.truth[["temp_stratum_for_lag"]] <- rep(0, nrow(df.truth))
            }
            truth.lag.indices <- generate_lag_matrix_indices(
                as.integer(as.factor(df.truth$year)),
                as.integer(as.factor(df.truth$location)),
                as.integer(as.factor(df.truth$temp_stratum_for_lag)),
                as.integer(as.factor(df.truth$source)),
                nrow(df.truth)
            )
            truth.n.lag.pairs <- length(truth.lag.indices) / 2
            truth.lag.values <- apply_lag_to_vector(df.truth$value, truth.lag.indices, rep(0, truth.n.lag.pairs), truth.n.lag.pairs)
            truth.rows.to.keep <- truth.lag.indices[rep(c(T, F), truth.n.lag.pairs)] + 1
            df.truth <- df.truth[truth.rows.to.keep, ]
            df.truth$value <- exp(truth.lag.values)
            df.truth$temp_stratum_for_lag <- NULL
            df.truth <- df.truth[!is.na(df.truth$value) & !is.infinite(df.truth$value), ]
            if (nrow(df.truth) == 0) df.truth <- NULL
        }
        if (!is.null(df.sim)) {
            df.sim$value <- log(df.sim$value)
            if (!is.null(df.sim$value.lower) && !is.null(df.sim$value.upper)) {
                df.sim$value.lower <- log(df.sim$value.lower)
                df.sim$value.upper <- log(df.sim$value.upper)
            }
            temp_stratum_cols <- c(
                if (!is.null(split.by) && "stratum" %in% names(df.sim)) "stratum" else NULL,
                if (!is.null(facet.by)) paste0("facet.by", seq_along(facet.by)[facet.by %in% names(df.sim)]) else NULL
            )
            if (length(temp_stratum_cols) > 0) {
                df.sim[["temp_stratum_for_lag"]] <- apply(df.sim[, temp_stratum_cols, drop = FALSE], 1, paste, collapse = "__")
            } else {
                df.sim[["temp_stratum_for_lag"]] <- rep(0, nrow(df.sim))
            }
            sim.lag.indices <- generate_lag_matrix_indices(
                as.integer(as.factor(df.sim$year)),
                as.integer(as.factor(df.sim$sim)),
                as.integer(as.factor(df.sim$temp_stratum_for_lag)),
                as.integer(as.factor(df.sim$simset)),
                nrow(df.sim)
            )
            sim.n.lag.pairs <- length(sim.lag.indices) / 2
            sim.lag.values <- apply_lag_to_vector(df.sim$value, sim.lag.indices, rep(0, sim.n.lag.pairs), sim.n.lag.pairs)
            sim.rows.to.keep <- sim.lag.indices[rep(c(T, F), sim.n.lag.pairs)] + 1
            if (!is.null(df.sim$value.lower) && !is.null(df.sim$value.upper)) {
                sim.lower.lag.values <- apply_lag_to_vector(df.sim$value.lower, sim.lag.indices, rep(0, sim.n.lag.pairs), sim.n.lag.pairs)
                sim.upper.lag.values <- apply_lag_to_vector(df.sim$value.upper, sim.lag.indices, rep(0, sim.n.lag.pairs), sim.n.lag.pairs)
            }
            df.sim <- df.sim[sim.rows.to.keep, ]
            df.sim$value <- exp(sim.lag.values)
            df.sim$temp_stratum_for_lag <- NULL
            if (!is.null(df.sim$value.lower) && !is.null(df.sim$value.upper)) {
                df.sim$value.lower <- exp(sim.lower.lag.values)
                df.sim$value.upper <- exp(sim.upper.lag.values)
            }
            df.sim <- df.sim[!is.na(df.sim$value) & !is.infinite(df.sim$value), ]
            if (nrow(df.sim) == 0) df.sim <- NULL
        }
    }


    #-- PACKAGE AND RETURN ----
    # Determine Y label
    y.label <- ""
    if (plot.which == "data.only" && !is.null(outcomes) && length(outcomes) > 0) {
        # Use units from the first outcome's metadata
        first_outcome_meta <- data.manager$outcome.info[[outcomes[1]]]$metadata
        if (!is.null(first_outcome_meta$units)) y.label <- first_outcome_meta$units
    } else if (!is.null(simset.list) && length(simset.list) > 0 && !is.null(outcomes) && length(outcomes) > 0) {
        # Use units from the first simset's metadata for the first outcome
        first_sim_meta <- simset.list[[1]]$outcome.metadata[[outcomes[1]]]
        if (!is.null(first_sim_meta$units)) y.label <- first_sim_meta$units
    }
    if (plot.year.lag.ratio) y.label <- paste0("Log difference in ", y.label)


    # Determine plot title
    plot.title <- NULL
    if (!is.null(title)) {
        if (title == "location") {
            loc <- NULL
            if (plot.which == "data.only" && !is.null(locations) && length(locations) > 0) {
                loc <- locations[[1]]
            } else if (!is.null(simset.list) && length(simset.list) > 0) {
                loc <- simset.list[[1]]$location
            }
            if (!is.null(loc)) {
                loc_name <- tryCatch(get.location.name(loc), error = function(e) loc) # Use tryCatch for safety
                plot.title <- paste0(loc_name, " (", loc, ")")
            }
        } else {
            plot.title <- title
        }
    }
    # browser()
    return(list(
        df.sim = df.sim,
        df.truth = df.truth,
        details = list(
            y.label = y.label,
            plot.title = plot.title,
            outcome.metadata.list = outcome.metadata.list,
            source.metadata.list = source.metadata.list,
            sim.labels.list = sim.labels.list
        )
    ))
}


# Renamed local version of jheem2::execute.simplot
# ** MODIFICATIONS MADE HERE **
execute_simplot_local <- function(prepared.plot.data,
                                  outcomes = NULL,
                                  split.by = NULL,
                                  facet.by = NULL,
                                  plot.which = c("sim.and.data", "sim.only", "data.only")[1],
                                  summary.type = c("individual.simulation", "mean.and.interval", "median.and.interval")[1],
                                  plot.year.lag.ratio = F,
                                  n.facet.rows = NULL,
                                  style.manager = get.default.style.manager(),
                                  debug = F) {
    if (debug) browser()
    # browser()
    #-- UNPACK DATA --#
    df.sim <- prepared.plot.data$df.sim
    df.truth <- prepared.plot.data$df.truth
    y.label <- prepared.plot.data$details$y.label
    plot.title <- prepared.plot.data$details$plot.title

    #-- PREPARE PLOT COLORS, SHADES, SHAPES, ETC. --#
    # Revert to original logic - assumes style.manager is valid and properties exist

    if (!is.null(df.sim)) {
        df.sim["linetype.sim.by"] <- df.sim[[style.manager$linetype.sim.by]] # Use [[ ]]
        df.sim["shape.sim.by"] <- df.sim[[style.manager$shape.sim.by]] # Use [[ ]]
        df.sim["color.sim.by"] <- df.sim[[style.manager$color.sim.by]] # Use [[ ]]
    }

    if (!is.null(df.truth)) {
        # make some other columns
        df.truth["location.type"] <- locations::get.location.type(df.truth$location) # Assuming locations package is available
        df.truth["shape.data.by"] <- df.truth[[style.manager$shape.data.by]] # Use [[ ]]
        df.truth["color.data.by"] <- df.truth[[style.manager$color.data.by]] # Use [[ ]]
        df.truth["shade.data.by"] <- df.truth[[style.manager$shade.data.by]] # Use [[ ]]

        # Combine color and shade (Original logic - might need adjustment if "" causes issues)
        if (style.manager$color.data.by == "stratum" && !is.null(df.truth$stratum) && all(df.truth$stratum == "")) {
            df.truth["color.and.shade.data.by"] <- df.truth["shade.data.by"]
        } else if (style.manager$shade.data.by == "stratum" && !is.null(df.truth$stratum) && all(df.truth$stratum == "")) {
            df.truth["color.and.shade.data.by"] <- df.truth["color.data.by"]
        } else {
            df.truth["color.and.shade.data.by"] <- do.call(paste, c(df.truth["shade.data.by"], df.truth["color.data.by"], list(sep = "__")))
        }
    }


    ## COLORS (Revert to original logic)
    colors.for.sim <- NULL
    color.data.primary.colors <- NULL

    sim.color.groups <- sort(unique(df.sim$color.sim.by))
    data.color.groups <- sort(unique(df.truth$color.data.by))

    # if coloring by the same thing, use the same palette (defaulting to SIM's palette) unless one is missing
    if (style.manager$color.sim.by == style.manager$color.data.by) {
        all.color.groups <- sort(union(sim.color.groups, data.color.groups))

        if (!is.null(df.sim)) {
            all.colors <- style.manager$get.sim.colors(length(all.color.groups))
        } else if (!is.null(df.truth)) {
            all.colors <- style.manager$get.data.colors(length(all.color.groups))
        } else {
            all.colors <- NULL
        } # doesn't matter?

        names(all.colors) <- all.color.groups
        colors.for.sim <- all.colors[sim.color.groups]
        color.data.primary.colors <- all.colors[data.color.groups]
    }
    # otherwise, assign colors individually
    else {
        if (!is.null(df.sim)) {
            colors.for.sim <- style.manager$get.sim.colors(length(sim.color.groups))
            names(colors.for.sim) <- sim.color.groups
        }
        if (!is.null(df.truth)) {
            color.data.primary.colors <- style.manager$get.data.colors(length(data.color.groups))
            names(color.data.primary.colors) <- data.color.groups
        }
    }

    ## RIBBON COLOR (Revert - original didn't define this separately)
    # color.ribbon.by = NULL
    # if (!is.null(df.sim)) {
    #     color.ribbon.by = ggplot2::alpha(colors.for.sim, style.manager$alpha.ribbon)
    # }

    ## SHADES FOR DATA (Revert to original logic)
    color.data.shaded.colors <- NULL
    if (!is.null(df.truth)) {
        color.data.shaded.colors <- unlist(lapply(color.data.primary.colors, function(prim.color) {
            style.manager$get.shades(base.color = prim.color, length(unique(df.truth$shade.data.by)))
        }))
        # This can lead to problems if we have either of these being "" because then we'll get an underscore that won't match the actual column values in the data frame (Original comment)
        if (identical(unique(df.truth$color.data.by), "")) {
            names(color.data.shaded.colors) <- unique(df.truth$shade.data.by)
        } else {
            names(color.data.shaded.colors) <- do.call(paste, c(expand.grid(unique(df.truth$shade.data.by), unique(df.truth$color.data.by)), list(sep = "__")))
        }
    }


    ## SHAPES (Revert to original logic)
    shapes.for.data <- NULL
    shapes.for.sim <- NULL
    if (!is.null(df.truth)) {
        shapes.for.data <- style.manager$get.shapes(length(unique(df.truth$shape.data.by)))
        names(shapes.for.data) <- unique(df.truth$shape.data.by)
    }
    if (!is.null(df.sim)) {
        shapes.for.sim <- style.manager$get.shapes(length(unique(df.sim$shape.sim.by)))
        names(shapes.for.sim) <- unique(df.sim$shape.sim.by)
    }
    all.shapes.for.scale <- c(shapes.for.data, shapes.for.sim)


    ## LINETYPES (Revert to original logic)
    linetypes.for.sim <- NULL
    if (!is.null(df.sim)) {
        linetypes.for.sim <- style.manager$get.linetypes(length(unique(df.sim$linetype.sim.by)))
        names(linetypes.for.sim) <- unique(df.sim$linetype.sim.by)
    }


    ## GROUPS for Lines vs Points (Sim Data)
    df.sim.groupids.one.member <- NULL
    df.sim.groupids.many.members <- NULL
    # Check if df.sim exists and has rows before proceeding
    if (!is.null(df.sim) && nrow(df.sim) > 0) {
        # Ensure groupid exists
        if (!"groupid" %in% names(df.sim)) {
            df.sim$groupid <- interaction(df.sim$outcome, df.sim$simset, df.sim$sim, df.sim$stratum, drop = TRUE, sep = "_")
        }
        # Proceed with splitting based on groupid counts
        groupid_counts <- table(df.sim$groupid)
        groupids.with.one.member <- names(groupid_counts[groupid_counts == 1])
        df.sim$groupid_has_one_member <- df.sim$groupid %in% groupids.with.one.member
        df.sim.groupids.one.member <- df.sim[df.sim$groupid_has_one_member, , drop = FALSE] # Use drop=FALSE
        df.sim.groupids.many.members <- df.sim[!df.sim$groupid_has_one_member, , drop = FALSE] # Use drop=FALSE
    }


    # --- MODIFICATION: Create hover text column in df.sim ---
    # Ensure df.sim exists and has rows before adding the column
    if (!is.null(df.sim) && nrow(df.sim) > 0) {
        # Ensure necessary columns exist for hover text creation
        base_hover_cols <- c("year", "value")
        ci_hover_cols <- c("value.lower", "value.upper")
        all_hover_cols <- c(base_hover_cols, ci_hover_cols)

        # Check which columns are actually present
        cols_present <- names(df.sim)
        has_base_cols <- all(base_hover_cols %in% cols_present)
        has_ci_cols <- all(ci_hover_cols %in% cols_present)

        if (has_base_cols) {
            df.sim$ci_hover_text <- sapply(1:nrow(df.sim), function(j) {
                # Use integer for year if appropriate, else keep as is
                year_val <- if (is.numeric(df.sim$year[j]) && !is.na(df.sim$year[j]) && df.sim$year[j] == floor(df.sim$year[j])) sprintf("%d", df.sim$year[j]) else sprintf("%.1f", df.sim$year[j])
                base_text <- sprintf("Year: %s\nValue: %.2f", year_val, round(df.sim$value[j], 2))

                # Add CI info if columns exist and values are not NA
                if (has_ci_cols && !is.na(df.sim$value.lower[j]) && !is.na(df.sim$value.upper[j])) {
                    ci_text <- sprintf(
                        "\nLower CI: %.2f\nUpper CI: %.2f",
                        round(df.sim$value.lower[j], 2),
                        round(df.sim$value.upper[j], 2)
                    )
                    return(paste0(base_text, ci_text))
                } else {
                    return(base_text)
                }
            })

            # Apply hover text to split dataframes if they exist
            if (!is.null(df.sim.groupids.many.members) && nrow(df.sim.groupids.many.members) > 0) {
                df.sim.groupids.many.members$ci_hover_text <- df.sim$ci_hover_text[match(rownames(df.sim.groupids.many.members), rownames(df.sim))]
            }
            if (!is.null(df.sim.groupids.one.member) && nrow(df.sim.groupids.one.member) > 0) {
                df.sim.groupids.one.member$ci_hover_text <- df.sim$ci_hover_text[match(rownames(df.sim.groupids.one.member), rownames(df.sim))]
            }
        } else {
            warning("Could not create hover text because required columns (year, value) are missing from df.sim.")
            # Add empty hover text column to prevent errors later
            df.sim$ci_hover_text <- ""
            if (!is.null(df.sim.groupids.many.members)) df.sim.groupids.many.members$ci_hover_text <- ""
            if (!is.null(df.sim.groupids.one.member)) df.sim.groupids.one.member$ci_hover_text <- ""
        }
    }
    # --- END MODIFICATION ---

    ## GROUPS (Revert to original logic)
    # break df.sim into two data frames, one for outcomes where the sim will be lines and the other for where it will be points
    df.sim.groupids.one.member <- NULL
    df.sim.groupids.many.members <- NULL
    if (!is.null(df.sim)) { # Original check
        # Ensure groupid exists before splitting
        if (!"groupid" %in% names(df.sim)) {
            df.sim$groupid <- interaction(df.sim$outcome %||% "o", df.sim$simset %||% "s", df.sim$sim %||% "i", df.sim$stratum %||% "t", drop = TRUE, sep = "_")
        }
        groupids.with.one.member <- setdiff(unique(df.sim$groupid), df.sim$groupid[which(duplicated(df.sim$groupid))])
        df.sim$groupid_has_one_member <- with(df.sim, groupid %in% groupids.with.one.member)
        df.sim.groupids.one.member <- subset(df.sim, groupid_has_one_member) # Original subset call
        df.sim.groupids.many.members <- subset(df.sim, !groupid_has_one_member) # Original subset call
    }


    #-- MAKE THE PLOT --# (Revert to original)
    # browser()
    rv <- ggplot2::ggplot()
    rv <- rv +
        ggplot2::labs(y = y.label) +
        ggplot2::ggtitle(plot.title) +
        ggplot2::scale_alpha(guide = "none")


    if (!plot.year.lag.ratio) {
        rv <- rv + ggplot2::scale_y_continuous(limits = c(0, NA), labels = scales::comma)
    } else {
        rv <- rv + ggplot2::scale_y_continuous(labels = scales::comma)
    }
    # browser()

    # SIM ELEMENTS (Revert to original structure, keeping text aesthetic and ribbon fix)
    if (!is.null(df.sim)) {
        # Note: the key to avoiding warning messages about scale is to only add a scale if it is used by the data frames that are actually plotted. (Original comment)

        # PLOT (Original structure)
        if (!is.null(split.by)) {
            # Original color scale placement
            rv <- rv + ggplot2::scale_color_manual(name = "sim color", values = colors.for.sim)
            # has.added.color.scale = T # Original variable, seems unused later

            if (nrow(df.sim.groupids.many.members) > 0) {
                rv <- rv + ggplot2::geom_line(data = df.sim.groupids.many.members, ggplot2::aes(
                    x = year, y = value, group = groupid,
                    linetype = linetype.sim.by,
                    color = color.sim.by,
                    linewidth = linewidth,
                    alpha = alpha,
                    text = ci_hover_text
                )) # ADDED text
            }
            if (nrow(df.sim.groupids.one.member) > 0) {
                rv <- rv +
                    ggplot2::geom_point(
                        data = df.sim.groupids.one.member, ggplot2::aes(
                            x = year, y = value, group = groupid, # Added group
                            size = size, # Original size mapping
                            fill = color.sim.by,
                            shape = shape.sim.by,
                            text = ci_hover_text
                        ), # ADDED text
                        show.legend = F
                    ) + # Original show.legend
                    ggplot2::scale_size_manual(values = c(size = 2)) # Original size scale
            }
            if (summary.type != "individual.simulation") {
                # MODIFIED: Use standard geom_ribbon
                rv <- rv + ggplot2::geom_ribbon(
                    data = df.sim.groupids.many.members, ggplot2::aes(
                        x = year, ymin = value.lower, ymax = value.upper, group = groupid, # Use groupid
                        fill = color.sim.by
                    ), # Map fill directly
                    alpha = style.manager$alpha.ribbon
                ) # Use style manager alpha
                # Removed outline.type = 'full' as it's not standard
                # Original fill scale placement
                rv <- rv + ggplot2::scale_fill_manual(name = "sim color", values = colors.for.sim)
            }
        } else { # Original else block for no split.by
            if (nrow(df.sim.groupids.many.members) > 0) {
                # Original logic for conditional color mapping
                if (style.manager$color.sim.by == "simset") {
                    rv <- rv + ggplot2::geom_line(data = df.sim.groupids.many.members, ggplot2::aes(
                        x = year, y = value, group = groupid,
                        linetype = linetype.sim.by,
                        color = color.sim.by, # Color mapped here
                        linewidth = linewidth,
                        alpha = alpha,
                        text = ci_hover_text
                    )) # ADDED text
                } else {
                    rv <- rv + ggplot2::geom_line(data = df.sim.groupids.many.members, ggplot2::aes(
                        x = year, y = value, group = groupid,
                        linetype = linetype.sim.by,
                        # No color mapping here in original
                        linewidth = linewidth,
                        alpha = alpha,
                        text = ci_hover_text
                    ))
                } # ADDED text
            }
            if (nrow(df.sim.groupids.one.member) > 0) {
                rv <- rv +
                    ggplot2::geom_point(data = df.sim.groupids.one.member, ggplot2::aes(
                        x = year, y = value, group = groupid, # Added group
                        size = size, # Original size mapping
                        fill = color.sim.by,
                        shape = shape.sim.by,
                        text = ci_hover_text
                    )) + # ADDED text
                    ggplot2::scale_size_manual(values = c(size = 2)) # Original size scale
            }

            if (summary.type != "individual.simulation") {
                # MODIFIED: Use standard geom_ribbon
                rv <- rv + ggplot2::geom_ribbon(
                    data = df.sim.groupids.many.members, ggplot2::aes(
                        x = year, ymin = value.lower, ymax = value.upper, group = groupid, # Use groupid
                        fill = color.sim.by
                    ), # Map fill directly
                    alpha = style.manager$alpha.ribbon
                ) # Use style manager alpha
                # Removed outline.type = 'full'
                # Remove the fill scale since we don't have more than one sim ribbon color (Original comment & logic)
                if (style.manager$color.sim.by == "stratum") {
                    rv <- rv + ggplot2::guides(fill = "none")
                }
            }
        }
        # Original scale placement (moved some inside conditional blocks above)
        if (nrow(df.sim.groupids.many.members) > 0) {
            rv <- rv + ggplot2::scale_linetype_manual(name = "sim linetype", values = linetypes.for.sim, breaks = names(linetypes.for.sim))
            rv <- rv + ggplot2::scale_linewidth(NULL, range = c(min(df.sim$linewidth), 1), guide = "none")
        }
        if (nrow(df.sim.groupids.one.member) > 0) {
            # Original fill scale placement for points
            rv <- rv + ggplot2::scale_fill_manual(name = "sim color", values = colors.for.sim)
            rv <- rv + ggplot2::scale_shape_manual(name = "sim shape", values = shapes.for.sim)
        }
        # Original conditional color/fill scale placement
        if (style.manager$color.sim.by == "simset") {
            rv <- rv + ggplot2::scale_color_manual(name = "sim color", values = colors.for.sim)
            # Fill scale might be redundant if added elsewhere, check original logic carefully
            # rv = rv + ggplot2::scale_fill_manual(name = "sim color", values = colors.for.sim) # Potentially remove if handled above
        }
    }
    # browser() (Original position)

    # DATA ELEMENTS (Revert to original structure)
    if (!is.null(df.truth)) {
        # if we already have a shape scale, clear it before adding new points (Original comment & logic)
        if (!is.null(df.sim.groupids.one.member) && nrow(df.sim.groupids.one.member) > 0) {
            rv <- rv + ggnewscale::new_scale("shape")
        }
        rv <- rv + ggnewscale::new_scale_fill() + ggplot2::scale_fill_manual(values = color.data.shaded.colors) # We're changing the scale because the data fills differently (Original comment)

        rv <- rv + ggplot2::guides(fill = ggplot2::guide_legend("data color", override.aes = list(shape = 21))) # Original guide

        # PLOT (Original structure)
        if (!is.null(split.by)) {
            rv <- rv + ggplot2::geom_point(data = df.truth, ggplot2::aes(
                x = year, y = value,
                fill = color.and.shade.data.by, # fill
                shape = shape.data.by
            ))
        } else {
            # Why is this plotting all black fill, even though we remade the fill scale?? (in Melissa's outcome="new" simplot call) (Original comment)
            rv <- rv + ggplot2::geom_point(data = df.truth, ggplot2::aes(x = year, y = value, size = "size", fill = color.and.shade.data.by, shape = shape.data.by), show.legend = F) + # Original mapping & show.legend
                ggplot2::scale_size_manual(values = c(size = 2)) # Original size scale
        }

        # Now create the shape scale, either for the first time or the second time (Original comment & logic)
        if (!is.null(df.sim.groupids.one.member) && nrow(df.sim.groupids.one.member) > 0) {
            rv <- rv + ggplot2::scale_shape_manual(name = "data shape", values = all.shapes.for.scale)
        } else {
            rv <- rv + ggplot2::scale_shape_manual(name = "data shape", values = all.shapes.for.scale)
        }
    }

    #---- (Original separator)
    # If don't have a split.by, and thus only 1 color for sim, probably, then remove legend for it. (Original comment & logic)
    if (style.manager$color.sim.by == "stratum" && is.null(split.by)) {
        rv <- rv + ggplot2::guides(color = "none")
    }
    # browser() (Original position)

    #-- FACET --# (Revert to original logic)
    if (is.null(facet.by)) {
        facet.formula <- as.formula("~outcome.display.name")
    } else {
        facet.formula <- as.formula(paste0("~outcome.display.name + ", paste(sapply(seq_along(facet.by), function(i) {
            paste0("facet.by", i)
        }), collapse = " + ")))
    }
    if (!is.null(df.sim) || !is.null(df.truth)) {
        if (!is.null(n.facet.rows)) {
            rv <- rv + ggplot2::facet_wrap(facet.formula, scales = "free_y", nrow = n.facet.rows)
        } else {
            rv <- rv + ggplot2::facet_wrap(facet.formula, scales = "free_y")
        }
    }
    # browser() (Original position)

    if (plot.year.lag.ratio) rv <- rv + ggplot2::xlab("latter year")

    rv
}

# Helper function (assuming it exists in jheem2 or global env)
# is.year.range <- function(x) { grepl("-", x) }
# get.location.name <- function(loc) { loc } # Placeholder

# Placeholder for style manager if not loaded globally
if (!exists("get.default.style.manager")) {
    get.default.style.manager <- function() {
        list(
            linetype.sim.by = "stratum",
            shape.sim.by = "stratum",
            color.sim.by = "simset",
            shape.data.by = "source",
            color.data.by = "stratum",
            shade.data.by = "location.type",
            linewidth.slope = 0.1, # Example value
            alpha.ribbon = 0.2, # Example value
            get.sim.colors = function(n) scales::hue_pal()(n),
            get.data.colors = function(n) scales::hue_pal()(n),
            get.shades = function(base.color, n) scales::gradient_n_pal(c(base.color, "white"))(seq(0, 0.5, length.out = n)), # Example shading
            get.shapes = function(n) (15:(15 + n - 1)), # Example shapes (filled)
            get.linetypes = function(n) (1:n) # Example linetypes
        )
    }
}
# Placeholder for data manager if not loaded globally
if (!exists("get.default.data.manager")) {
    get.default.data.manager <- function() {
        NULL
    } # Needs a proper mock/stub if used
}
# Placeholder for ontology check if not loaded globally
if (!exists("is.ontology")) {
    is.ontology <- function(x) {
        FALSE
    } # Simple placeholder
}
# Placeholder for get.ontology.mapping if not loaded globally
if (!exists("get.ontology.mapping")) {
    get.ontology.mapping <- function(from, to) {
        NULL
    } # Simple placeholder
}
# Placeholder for locations::get.location.type if not loaded
# Use tryCatch to define placeholder only if package/function isn't found
tryCatch(
    {
        if (!exists("get.location.type", where = "package:locations", mode = "function")) {
            get.location.type <- function(location) {
                return("Unknown")
            }
        }
    },
    error = function(e) {
        get.location.type <- function(location) {
            return("Unknown")
        }
    }
)

# Placeholder for is.year.range
if (!exists("is.year.range")) {
    is.year.range <- function(x) {
        grepl("-", x)
    }
}
# Placeholder for get.location.name
if (!exists("get.location.name")) {
    get.location.name <- function(loc) {
        loc
    }
}
# Placeholders for lag functions if not available
if (!exists("generate_lag_matrix_indices")) {
    generate_lag_matrix_indices <- function(...) {
        integer(0)
    } # Return empty integer vector
}
if (!exists("apply_lag_to_vector")) {
    apply_lag_to_vector <- function(...) {
        numeric(0)
    } # Return empty numeric vector
}
