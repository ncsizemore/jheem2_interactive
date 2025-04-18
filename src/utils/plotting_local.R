# We need access to the prepare.plot function from PLOTS_simplot.R

library(plotly)

# source("R/PLOTS_simplot.R")

# Need access to the Data Manager

# source("R/DATA_MANAGER_data_manager.R")

#' @param ... One or more of either (1) jheem.simulation.set objects or (2) lists containing only jheem.simulation or jheem.simset objects
#' @param outcomes A character vector of which simulation outcomes to plot
#' @param split.by A character vector of dimensions for which to make different lines
#' @param facet.by A character vector of dimensions for which to make different panels
#' @param dimension.values
#' @param data.manager The data.manager from which to draw real-world data for the plots
#' @param style.manager An object of class 'jheem.style.manager' specifying style attributes

# Questions for Todd and Andrew: October 7th, 2024

# - Best way to setup the environment to test/work on plot.simulations
#    - how to properly reference prepare.plot
# No source() commands in any files as will be used as
# package
# source_jheem2_package is all we need in the test
#
#    - how to get access to data.manager / style.manager functions
#    - loading up the simset data

# - How to deal with parameters that are not available for plot.simulations
#    - prepare.plot
#      - corresponding.data.outcomes
#      - target.ontology
#      - plot.which
#      - summary.type
#      - plot.year.lag.ratio
#    - execute.simplot:
#      - n.facet.rows

#  Add these parameters to the plot.simulations function, with
#  the exception of plot.which, which is "both"

# Questions for Todd and Andrew: October 22nd, 2024

# Andrew has some cleaning functionality at the beginning of sim plot;
# validation, etc.  Would it be ok if I extracted this functionality
# into another function and returned a list with the modified values?

# Which are the correct values for plot.which?

# Where should I setup the project for the new hierarchy to work?
# I have currently:
# JHEEM/code
#     -> jheem2
#     -> jheem_analyses
# JHEEM/cached
#     -> (cached objects)
# and my project is setup in the JHEEM directory

# simplot <- function(...,
#                     outcomes=NULL,
#                     corresponding.data.outcomes = NULL,
#                     split.by = NULL,
#                     facet.by = NULL,
#                     dimension.values = list(),
#                     target.ontology = NULL,
#                     plot.which = c('sim.and.data', 'sim.only')[1],
#                     summary.type = c('individual.simulation', 'mean.and.interval', 'median.and.interval')[1],
#                     plot.year.lag.ratio = F,
#                     title = "location",
#                     n.facet.rows = NULL,
#                     data.manager = get.default.data.manager(),
#                     style.manager = get.default.style.manager(),
#                     debug = F)


plot.simulations_local <- function(...,
                                   outcomes,
                                   corresponding.data.outcomes = NULL,
                                   split.by = NULL,
                                   facet.by = NULL,
                                   dimension.values = list(),
                                   target.ontology = NULL,
                                   summary.type = c("individual.simulation", "mean.and.interval", "median.and.interval")[1],
                                   plot.year.lag.ratio = F,
                                   title = "location",
                                   n.facet.rows = NULL,
                                   interval.coverate = 0.95,
                                   data.manager = get.default.data.manager(),
                                   # style.manager = get.default.style.manager('plotly'),
                                   style.manager = get.default.style.manager(),
                                   hide.legend = FALSE) {
    plot.which <- "sim.and.data"

    simset <- list(...)[[1]]

    plot.data <- plot.data.validation(
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
    outcomes <- plot.data$outcomes # Make sure outcomes is updated if validation modifies it

    prepared.plot.data <- prepare.plot(simset.list,
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
        data.manager = data.manager,
        debug = F
    )

    execute.plotly.plot_local(prepared.plot.data,
        outcomes = outcomes, # Pass the potentially updated outcomes
        split.by = split.by,
        facet.by = facet.by,
        plot.which = plot.which,
        summary.type = summary.type,
        plot.year.lag.ratio = plot.year.lag.ratio,
        n.facet.rows = n.facet.rows,
        style.manager = style.manager,
        debug = debug,
        hide.legend = hide.legend
    )
}
execute.plotly.plot_local <- function(prepared.plot.data,
                                      outcomes = NULL,
                                      split.by = NULL,
                                      facet.by = NULL,
                                      plot.which = "sim.and.data",
                                      summary.type = c("individual.simulation", "mean.and.interval", "median.and.interval")[1],
                                      plot.year.lag.ratio = F,
                                      n.facet.rows = NULL,
                                      style.manager = get.default.style.manager(),
                                      debug = F,
                                      hide.legend = FALSE) {
    df.sim <- prepared.plot.data$df.sim
    df.truth <- prepared.plot.data$df.truth
    y.label <- prepared.plot.data$details$y.label # This might need adjustment if multiple outcomes have different labels
    plot.title <- prepared.plot.data$details$plot.title
    outcome.metadata <- prepared.plot.data$details$outcome.metadata

    #-- PREPARE PLOT COLORS, SHADES, SHAPES, ETC. --#

    if (!is.null(df.sim)) {
        # Ensure style columns exist before assignment
        if (!style.manager$linetype.sim.by %in% names(df.sim)) df.sim[[style.manager$linetype.sim.by]] <- ""
        if (!style.manager$shape.sim.by %in% names(df.sim)) df.sim[[style.manager$shape.sim.by]] <- ""
        if (!style.manager$color.sim.by %in% names(df.sim)) df.sim[[style.manager$color.sim.by]] <- ""

        df.sim["linetype.sim.by"] <- df.sim[style.manager$linetype.sim.by]
        df.sim["shape.sim.by"] <- df.sim[style.manager$shape.sim.by]
        df.sim["color.sim.by"] <- df.sim[style.manager$color.sim.by]
    }


    if (!is.null(df.truth)) {
        # Ensure style columns exist before assignment
        if (!style.manager$shape.data.by %in% names(df.truth)) df.truth[[style.manager$shape.data.by]] <- ""
        if (!style.manager$color.data.by %in% names(df.truth)) df.truth[[style.manager$color.data.by]] <- ""
        if (!style.manager$shade.data.by %in% names(df.truth)) df.truth[[style.manager$shade.data.by]] <- ""
        if (!"stratum" %in% names(df.truth)) df.truth[["stratum"]] <- "" # Ensure stratum exists for logic below

        # make some other columns
        df.truth["location.type"] <- locations::get.location.type(df.truth$location)
        df.truth["shape.data.by"] <- df.truth[style.manager$shape.data.by]
        df.truth["color.data.by"] <- df.truth[style.manager$color.data.by]
        df.truth["shade.data.by"] <- df.truth[style.manager$shade.data.by]
        if (style.manager$color.data.by == "stratum" && !is.null(df.truth$stratum) && all(df.truth$stratum == "")) {
            df.truth["color.and.shade.data.by"] <- df.truth["shade.data.by"]
        } else if (style.manager$shade.data.by == "stratum" && !is.null(df.truth$stratum) && all(df.truth$stratum == "")) {
            df.truth["color.and.shade.data.by"] <- df.truth["color.data.by"]
        } else {
            df.truth["color.and.shade.data.by"] <- do.call(paste, c(df.truth["shade.data.by"], df.truth["color.data.by"], list(sep = "__")))
        }
    }

    ## COLORS
    colors.for.sim <- NULL
    color.data.primary.colors <- NULL

    sim.color.groups <- if (!is.null(df.sim)) sort(unique(df.sim$color.sim.by)) else character(0)
    data.color.groups <- if (!is.null(df.truth)) sort(unique(df.truth$color.data.by)) else character(0)

    # if coloring by the same thing, use the same palette (defaulting to SIM's palette) unless one is missing
    if (style.manager$color.sim.by == style.manager$color.data.by) {
        all.color.groups <- sort(union(sim.color.groups, data.color.groups))

        if (length(all.color.groups) > 0) {
            if (!is.null(df.sim)) {
                all.colors <- style.manager$get.sim.colors(length(all.color.groups))
            } else if (!is.null(df.truth)) {
                all.colors <- style.manager$get.data.colors(length(all.color.groups))
            } else {
                all.colors <- NULL
            }
            if (!is.null(all.colors)) names(all.colors) <- all.color.groups
            colors.for.sim <- all.colors[sim.color.groups]
            color.data.primary.colors <- all.colors[data.color.groups]
        }
    } else { # otherwise, assign colors individually
        if (length(sim.color.groups) > 0) {
            colors.for.sim <- style.manager$get.sim.colors(length(sim.color.groups))
            names(colors.for.sim) <- sim.color.groups
        }
        if (length(data.color.groups) > 0) {
            color.data.primary.colors <- style.manager$get.data.colors(length(data.color.groups))
            names(color.data.primary.colors) <- data.color.groups
        }
    }

    ## RIBBON COLOR
    color.ribbon.by <- NULL
    if (!is.null(df.sim) && length(colors.for.sim) > 0) {
        # Ensure names match before applying alpha
        valid_colors_for_ribbon <- colors.for.sim[!is.na(names(colors.for.sim))]
        if (length(valid_colors_for_ribbon) > 0) {
            color.ribbon.by <- ggplot2::alpha(valid_colors_for_ribbon, style.manager$alpha.ribbon)
            # Make sure names are preserved if alpha returns unnamed vector for single color
            if (is.null(names(color.ribbon.by)) && length(valid_colors_for_ribbon) == 1) {
                names(color.ribbon.by) <- names(valid_colors_for_ribbon)
            }
        }
    }


    ## SHADES FOR DATA
    color.data.shaded.colors <- NULL
    if (!is.null(df.truth) && length(color.data.primary.colors) > 0) {
        shade.data.groups <- unique(df.truth$shade.data.by)
        if (length(shade.data.groups) > 0) {
            color.data.shaded.colors <- unlist(lapply(color.data.primary.colors, function(prim.color) {
                style.manager$get.shades(base.color = prim.color, length(shade.data.groups))
            }))
            # This can lead to problems if we have either of these being "" because then we'll get an underscore that won't match the actual column values in the data frame
            if (identical(unique(df.truth$color.data.by), "")) {
                names(color.data.shaded.colors) <- shade.data.groups
            } else {
                # Ensure expand.grid inputs are unique factors/characters
                shade_levels <- unique(as.character(df.truth$shade.data.by))
                color_levels <- unique(as.character(df.truth$color.data.by))
                if (length(shade_levels) > 0 && length(color_levels) > 0) {
                    name_grid <- expand.grid(shade_levels, color_levels)
                    names(color.data.shaded.colors) <- do.call(paste, c(name_grid, list(sep = "__")))
                }
            }
        }
    }

    ## SHAPES
    shapes.for.data <- NULL
    shapes.for.sim <- NULL
    data.shape.groups <- if (!is.null(df.truth)) unique(df.truth$shape.data.by) else character(0)
    sim.shape.groups <- if (!is.null(df.sim)) unique(df.sim$shape.sim.by) else character(0)

    if (length(data.shape.groups) > 0) {
        shapes.for.data <- style.manager$get.shapes(length(data.shape.groups))
        names(shapes.for.data) <- data.shape.groups
    }
    if (length(sim.shape.groups) > 0) {
        shapes.for.sim <- style.manager$get.shapes(length(sim.shape.groups))
        names(shapes.for.sim) <- sim.shape.groups
    }
    all.shapes.for.scale <- c(shapes.for.data, shapes.for.sim)

    ## LINETYPES
    linetypes.for.sim <- NULL
    sim.linetype.groups <- if (!is.null(df.sim)) unique(df.sim$linetype.sim.by) else character(0)
    if (length(sim.linetype.groups) > 0) {
        linetypes.for.sim <- style.manager$get.linetypes(length(sim.linetype.groups))
        names(linetypes.for.sim) <- sim.linetype.groups
        # Convert ggplot linetypes to plotly dash types
        linetypes.for.sim <- gsub("dashed", "dash", linetypes.for.sim)
        linetypes.for.sim <- gsub("dotted", "dot", linetypes.for.sim)
        linetypes.for.sim <- gsub("solid", "solid", linetypes.for.sim) # Ensure solid maps correctly
        # Add other mappings if needed (dotdash, longdash, twodash)
    }


    ## GROUPS (Split sim data for line vs point rendering)
    df.sim.groupids.one.member <- NULL
    df.sim.groupids.many.members <- NULL
    if (!is.null(df.sim)) {
        # Ensure groupid exists
        if (!"groupid" %in% names(df.sim)) df.sim$groupid <- interaction(df.sim$outcome, df.sim$simset, df.sim$sim, df.sim$stratum %||% "", sep = "_")

        groupids.with.one.member <- setdiff(unique(df.sim$groupid), df.sim$groupid[which(duplicated(df.sim$groupid))])
        df.sim$groupid_has_one_member <- with(df.sim, groupid %in% groupids.with.one.member)
        df.sim.groupids.one.member <- subset(df.sim, groupid_has_one_member)
        df.sim.groupids.many.members <- subset(df.sim, !groupid_has_one_member)
    }

    # PLOTLY PLOTS

    plotly.debug <- FALSE
    # Mapping the ggplot marker shapes into plotly symbols
    marker.mappings <- unlist(lapply(shapes.for.data, function(gg_shape) {
        if (gg_shape == 21) {
            return("circle")
        }
        if (gg_shape == 22) {
            return("square")
        }
        if (gg_shape == 23) {
            return("diamond")
        }
        if (gg_shape == 24) {
            return("triangle-up")
        }
        if (gg_shape == 25) {
            return("triangle-down")
        }
        # Add more mappings if other shapes are used
        return("circle") # Default
    }))

    sim.trace.count <- 0
    trace.in.legend <- list()

    build.marker.traces <- function(trace.data, base.trace, clean.group.id) {
        # Simplified version for now, assuming one shape/color per trace group for data
        # TODO: Revisit if complex shape/color mapping needed for data points like in original code
        unique.shapes <- unique(trace.data$marker.shapes)
        all.traces <- list()

        for (shape in unique.shapes) {
            shape.data <- subset(trace.data, marker.shapes == shape)
            if (nrow(shape.data) == 0) next

            col <- if (is.null(shape.data$marker.colors[1])) "#000000" else shape.data$marker.colors[1]
            sym <- if (is.null(shape.data$marker.shapes[1])) "circle" else shape.data$marker.shapes[1]

            trace <- base.trace
            trace$showlegend <- FALSE # Individual points usually don't need legends
            trace$x <- shape.data$year
            trace$y <- shape.data$value
            trace$mode <- "markers" # Ensure mode is markers
            trace$type <- "scatter" # Ensure type is scatter

            trace[["marker"]] <- list(
                color = col,
                symbol = sym,
                line = list(
                    color = "#202020", # Outline color
                    width = 1
                )
            )
            # Add hover text (optional)
            trace$text <- paste("Year:", shape.data$year, "<br>Value:", shape.data$value)
            trace$hoverinfo <- "text"

            all.traces <- append(all.traces, list(trace))
        }
        return(all.traces)

        # Original complex legend building logic removed for simplification, can be added back if needed
    }

    inner.collector <- function(cat.list,
                                data.for.this.facet,
                                trace.column,
                                marker.type,
                                current.facet) {
        trace.list <- list() # Collects all output traces

        for (trace_id in cat.list) {
            # Ensure trace_id is treated as character for subsetting factors
            trace_id_char <- as.character(trace_id)
            trace.data <- subset(
                data.for.this.facet,
                as.character(data.for.this.facet[[trace.column]]) == trace_id_char
            )

            if (nrow(trace.data) == 0) next # Skip if no data for this specific trace_id

            clean.group.id <- trace_id_char
            is.ribbon <- "value.upper" %in% names(trace.data) && "value.lower" %in% names(trace.data) && any(!is.na(trace.data$value.upper)) && any(!is.na(trace.data$value.lower))

            # Determine axis names based on facet index
            xaxis_name <- if (current.facet == 1) "x" else paste0("x", current.facet)
            yaxis_name <- if (current.facet == 1) "y" else paste0("y", current.facet)

            if (is.ribbon) {
                # Find the corresponding base color for the ribbon fill
                # This assumes color.ribbon.by uses the same names/groups as colors.for.sim
                # Need to handle cases where trace_id might not directly match a name (e.g., if trace_id is groupid)
                ribbon_fill_color_name <- trace.data$color.sim.by[1] # Assuming color.sim.by determines ribbon color group
                fill_color <- if (!is.null(color.ribbon.by) && ribbon_fill_color_name %in% names(color.ribbon.by)) {
                    color.ribbon.by[[ribbon_fill_color_name]]
                } else {
                    "rgba(128,128,128,0.2)" # Default transparent grey if no match
                }
                # Ensure fill_color is a valid color string
                if (is.null(fill_color) || is.na(fill_color)) fill_color <- "rgba(128,128,128,0.2)"

                # Order data by year for correct ribbon shape
                trace.data <- trace.data[order(trace.data$year), ]

                upper.trace <- list(
                    type = "scatter",
                    mode = "lines",
                    name = paste0(clean.group.id, ".max"), # Less relevant if not shown in legend
                    x = trace.data$year,
                    y = trace.data$value.upper,
                    xaxis = xaxis_name,
                    yaxis = yaxis_name,
                    line = list(width = 0), # No line for bounds
                    fill = NULL,
                    showlegend = FALSE,
                    hoverinfo = "skip"
                )

                lower.trace <- list(
                    type = "scatter",
                    mode = "lines",
                    name = paste0(clean.group.id, ".min"), # Less relevant if not shown in legend
                    x = trace.data$year,
                    y = trace.data$value.lower,
                    xaxis = xaxis_name,
                    yaxis = yaxis_name,
                    line = list(width = 0), # No line for bounds
                    fill = "tonexty", # Fill area between this trace and the previous one (upper.trace)
                    fillcolor = fill_color,
                    showlegend = FALSE,
                    hoverinfo = "skip"
                )
            }

            # Core base trace (line or marker)
            base.trace <- list(
                type = "scatter",
                mode = if (marker.type == "line") "lines" else "markers",
                name = clean.group.id, # Used for legend identification
                x = trace.data$year,
                y = trace.data$value,
                xaxis = xaxis_name,
                yaxis = yaxis_name
            )

            if (marker.type == "line") {
                sim.trace.count <<- sim.trace.count + 1
                # Use pre-calculated line color and shape, provide defaults if missing
                col <- trace.data$line.color[1] %||% style.manager$get.sim.colors(1)
                mark <- trace.data$line.shape[1] %||% "solid" # Default linetype

                # Legend handling: Show only one entry per unique color/linetype combination
                trace.key <- paste(col, mark, sep = "_")
                if (!hide.legend && is.null(trace.in.legend[[trace.key]])) {
                    base.trace$showlegend <- TRUE
                    trace.in.legend[[trace.key]] <<- TRUE
                } else {
                    base.trace$showlegend <- FALSE
                }

                base.trace[["line"]] <- list(dash = mark, color = col)
                # Add hover text
                base.trace$text <- paste("Year:", trace.data$year, "<br>Value:", round(trace.data$value, 2)) # Example hover text
                base.trace$hoverinfo <- "text+name" # Show trace name and custom text

                if (is.ribbon) {
                    # Add ribbon bounds first, then the central line
                    trace.list <- append(trace.list, list(upper.trace, lower.trace, base.trace))
                } else {
                    trace.list <- append(trace.list, list(base.trace))
                }
            } else if (marker.type == "marker") {
                # Use build.marker.traces for potentially complex marker styling
                marker.traces <- build.marker.traces(trace.data, base.trace, clean.group.id)
                trace.list <- append(trace.list, marker.traces)
            }
        }

        return(trace.list)
    }



    collect.traces.for.facet <- function(split.categories,
                                         data.for.this.facet,
                                         local.split.by, # The actual column name for splitting (e.g., "stratum" or value of split.by)
                                         trace.column, # The column defining individual traces (e.g., "groupid" or "stratum")
                                         marker.type,
                                         current.facet) {
        rv <- list()
        if (is.null(split.categories) || is.null(local.split.by)) { # No splitting needed
            # Ensure trace.column exists
            if (!trace.column %in% names(data.for.this.facet)) {
                warning(paste("Trace column", trace.column, "not found in data for facet", current.facet))
                return(list())
            }
            category.list <- unique(data.for.this.facet[[trace.column]])
            raw.traces <- inner.collector(
                category.list,
                data.for.this.facet,
                trace.column,
                marker.type,
                current.facet
            )
            rv <- append(rv, raw.traces)
        } else { # Split by the specified column
            # Ensure local.split.by column exists
            if (!local.split.by %in% names(data.for.this.facet)) {
                warning(paste("Split column", local.split.by, "not found in data for facet", current.facet))
                # Fallback: treat as if no split needed
                category.list <- unique(data.for.this.facet[[trace.column]])
                raw.traces <- inner.collector(category.list, data.for.this.facet, trace.column, marker.type, current.facet)
                rv <- append(rv, raw.traces)
            } else {
                # Proceed with splitting
                for (spl.cat in split.categories) {
                    spl.cat.char <- as.character(spl.cat) # Ensure character for subsetting factors
                    data.for.this.split <- subset(
                        data.for.this.facet,
                        as.character(data.for.this.facet[[local.split.by]]) == spl.cat.char
                    )
                    if (nrow(data.for.this.split) == 0) next # Skip if no data for this split category

                    # Ensure trace.column exists in the split data
                    if (!trace.column %in% names(data.for.this.split)) {
                        warning(paste("Trace column", trace.column, "not found in split data for facet", current.facet, "split", spl.cat.char))
                        next
                    }

                    category.list <- unique(data.for.this.split[[trace.column]])
                    raw.traces <- inner.collector(
                        category.list,
                        data.for.this.split, # Pass the subsetted data
                        trace.column, marker.type,
                        current.facet
                    )
                    rv <- append(rv, raw.traces)
                } # End of splits loop
            }
        }
        return(rv)
    }

    # Helper for properly creating the y.axis labels for the figures
    y.axis.label.helper <- function(outcome.metadata, outcome) {
        # Check if outcome exists in metadata
        if (!outcome %in% names(outcome.metadata)) {
            warning(paste("Outcome", outcome, "not found in outcome.metadata. Using outcome name as label."))
            return(outcome)
        }
        meta <- outcome.metadata[[outcome]]
        # Check for expected fields, provide defaults if missing
        label <- meta$axis.name %||% meta$display.name %||% outcome # Fallback label logic
        unit <- meta$units %||% ""
        # We want to prevent a 'Cases (cases)' situation here
        if (unit != "" && tolower(label) == tolower(unit)) {
            return(label)
        } else if (unit != "") {
            return(paste0(label, " (", unit, ")"))
        } else {
            return(label) # No unit to add
        }
    }
    # Draw the plots

    # Define the list structure
    # Initialize the plotly object as a list
    # Initialize the plotly object as a list
    fig <- list(data = list(), layout = list())
    fig$layout$annotations <- list() # Initialize annotations list earlier


    # Add labels for the y-axis and a title for the plot
    # Only set main title if there's just one plot/facet
    # fig$layout$title <- list(text = plot.title) # Moved to layout section

    # Each figure will need a y axis label, but that will be determined by the outcome,
    # So we should have a vector of y axis labels that the layout can use when laying
    # out the plot
    # y.axis.labels <- c() # This is now calculated after facets are determined

    # Remove alpha guide (no direct equivalent in Plotly)
    # Nothing to do for alpha guides since they don’t exist in Plotly

    # Determine combined faceting columns and create interaction term
    # Use facet.by if provided, otherwise only 'outcome'
    facet_cols_to_use <- if (!is.null(facet.by)) c("outcome", facet.by) else "outcome"
    combined_facet_col <- "combined_facet"
    all_combined_facets <- character(0) # Initialize empty vector

    # Helper function to safely create interaction term
    create_interaction <- function(df, cols, new_col_name) {
        # Check if all columns exist
        missing_cols <- setdiff(cols, names(df))
        if (length(missing_cols) > 0) {
            # Check if missing cols are generated facet.byX cols
            generated_facet_cols <- grep("^facet\\.by[0-9]+$", names(df), value = TRUE)
            original_facet_by_cols <- setdiff(cols, "outcome") # Get the original facet.by names requested

            if (length(original_facet_by_cols) > 0 && length(generated_facet_cols) == length(original_facet_by_cols)) {
                # If prepare.plot likely renamed facet.by to facet.byX, use those
                cols_to_interact <- c("outcome", generated_facet_cols)
                # Final check if these generated columns actually exist
                missing_generated <- setdiff(cols_to_interact, names(df))
                if (length(missing_generated) > 0) {
                    stop(paste("Missing required generated faceting columns:", paste(missing_generated, collapse = ", ")))
                }
            } else {
                # If it's not the generated columns case, it's a real error
                stop(paste("Missing required faceting columns:", paste(missing_cols, collapse = ", ")))
            }
        } else {
            # All original columns exist
            cols_to_interact <- cols
        }
        # Create interaction term using the determined columns
        df[[new_col_name]] <- interaction(df[, cols_to_interact, drop = FALSE], sep = " | ")
        return(df)
    }

    if (!is.null(df.sim)) {
        df.sim <- create_interaction(df.sim, facet_cols_to_use, combined_facet_col)
        all_combined_facets <- union(all_combined_facets, unique(df.sim[[combined_facet_col]]))
        # Also apply to one_member/many_members df if they exist
        if (!is.null(df.sim.groupids.one.member) && nrow(df.sim.groupids.one.member) > 0) {
            df.sim.groupids.one.member <- create_interaction(df.sim.groupids.one.member, facet_cols_to_use, combined_facet_col)
        }
        if (!is.null(df.sim.groupids.many.members) && nrow(df.sim.groupids.many.members) > 0) {
            df.sim.groupids.many.members <- create_interaction(df.sim.groupids.many.members, facet_cols_to_use, combined_facet_col)
        }
    }
    if (!is.null(df.truth)) {
        df.truth <- create_interaction(df.truth, facet_cols_to_use, combined_facet_col)
        all_combined_facets <- union(all_combined_facets, unique(df.truth[[combined_facet_col]]))
    }

    # Calculate final facet categories and count
    facet.categories <- sort(unique(as.character(all_combined_facets))) # Ensure character and unique
    figure.count <- length(facet.categories)

    # Prepare y-axis labels based on the outcome part of the combined facet category
    outcome_from_facet <- function(facet_str) {
        strsplit(as.character(facet_str), " | ", fixed = TRUE)[[1]][1]
    }
    # Ensure outcome.metadata names are accessible and match outcomes vector
    if (is.null(names(outcome.metadata)) || !all(outcomes %in% names(outcome.metadata))) {
        # Attempt to fix names if possible, otherwise warn
        if (length(outcome.metadata) == length(outcomes)) {
            names(outcome.metadata) <- outcomes
            warning("Outcome metadata was unnamed; assigned names based on 'outcomes' parameter.")
        } else {
            warning("Outcome metadata names are missing or do not match 'outcomes'. Y-axis labels may be incorrect.")
        }
    }
    fig$y.axis.labels <- sapply(facet.categories, function(cat) {
        outcome_name <- outcome_from_facet(cat)
        if (!outcome_name %in% names(outcome.metadata)) {
            warning(paste("Outcome", outcome_name, "from facet category not found in outcome.metadata. Using outcome name as label."))
            return(outcome_name) # Use outcome name as fallback label
        }
        y.axis.label.helper(outcome.metadata, outcome_name)
    }, USE.NAMES = FALSE)

    # Calculate global year range across both datasets
    all_years <- c()
    if (!is.null(df.sim) && "year" %in% names(df.sim)) {
        all_years <- c(all_years, df.sim$year)
    }
    if (!is.null(df.truth) && "year" %in% names(df.truth)) {
        all_years <- c(all_years, df.truth$year)
    }
    global_year_range <- NULL
    if (length(all_years) > 0) {
        # Ensure years are numeric and remove NA/Inf before calculating range
        numeric_years <- suppressWarnings(as.numeric(all_years))
        valid_years <- numeric_years[!is.na(numeric_years) & is.finite(numeric_years)]
        if (length(valid_years) > 0) {
            global_year_range <- range(valid_years)
        }
    }
    # Add padding to range if desired (e.g., +/- 1 year)
    # if (!is.null(global_year_range)) {
    #    global_year_range <- c(global_year_range[1] - 1, global_year_range[2] + 1)
    # }


    # SIMULATION ELEMENTS
    if (!is.null(df.sim)) {
        # Since this is simulation data, the marker type is "line"
        marker.type <- "line"

        if (plotly.debug) {
            cat("SIM\n\n")
        }

        # Add color/shape info to sim dataframes if they exist
        if (!is.null(df.sim.groupids.many.members) && nrow(df.sim.groupids.many.members) > 0) {
            df.sim.groupids.many.members$line.color <-
                unlist(lapply(df.sim.groupids.many.members$color.sim.by, function(val) {
                    # Provide default if val is NA, NULL, "", or not in names
                    if (is.null(val) || is.na(val) || val == "" || is.null(colors.for.sim[[val]])) style.manager$get.sim.colors(1) else colors.for.sim[[val]]
                }))
            df.sim.groupids.many.members$line.shape <-
                unlist(lapply(df.sim.groupids.many.members$linetype.sim.by, function(val) {
                    # Provide default if val is NA, NULL, "", or not in names
                    if (is.null(val) || is.na(val) || val == "" || is.null(linetypes.for.sim[[val]])) "solid" else linetypes.for.sim[[val]]
                }))
        }
        if (!is.null(df.sim.groupids.one.member) && nrow(df.sim.groupids.one.member) > 0) {
            df.sim.groupids.one.member$line.color <-
                unlist(lapply(df.sim.groupids.one.member$color.sim.by, function(val) {
                    if (is.null(val) || is.na(val) || val == "" || is.null(colors.for.sim[[val]])) style.manager$get.sim.colors(1) else colors.for.sim[[val]]
                }))
            df.sim.groupids.one.member$line.shape <-
                unlist(lapply(df.sim.groupids.one.member$linetype.sim.by, function(val) {
                    if (is.null(val) || is.na(val) || val == "" || is.null(linetypes.for.sim[[val]])) "solid" else linetypes.for.sim[[val]]
                }))
        }


        # Iterate through the combined facet categories
        for (facet_index in seq_along(facet.categories)) {
            fac.cat <- facet.categories[facet_index]
            current.facet <- facet_index # Use index for axis mapping

            # Subset data for the current combined facet
            data.for.this.facet.many <- NULL
            if (!is.null(df.sim.groupids.many.members) && nrow(df.sim.groupids.many.members) > 0) {
                data.for.this.facet.many <- subset(
                    df.sim.groupids.many.members,
                    as.character(df.sim.groupids.many.members[[combined_facet_col]]) == as.character(fac.cat) # Ensure comparison works with factors
                )
            }
            data.for.this.facet.one <- NULL
            if (!is.null(df.sim.groupids.one.member) && nrow(df.sim.groupids.one.member) > 0) {
                data.for.this.facet.one <- subset(
                    df.sim.groupids.one.member,
                    as.character(df.sim.groupids.one.member[[combined_facet_col]]) == as.character(fac.cat) # Ensure comparison works with factors
                )
            }

            # Check if there's any data for this facet
            if ((is.null(data.for.this.facet.many) || nrow(data.for.this.facet.many) == 0) &&
                (is.null(data.for.this.facet.one) || nrow(data.for.this.facet.one) == 0)) {
                next # Skip to next facet if no data
            }

            # Determine split categories *within this facet*
            split.categories <- NULL
            if (!is.null(split.by)) {
                # Ensure split.by column exists in the relevant dataframe before accessing
                valid_split_many <- !is.null(data.for.this.facet.many) && split.by %in% names(data.for.this.facet.many)
                valid_split_one <- !is.null(data.for.this.facet.one) && split.by %in% names(data.for.this.facet.one)
                current_split_categories <- unique(c(
                    if (valid_split_many) as.character(data.for.this.facet.many[[split.by]]) else NULL,
                    if (valid_split_one) as.character(data.for.this.facet.one[[split.by]]) else NULL
                ))
                # Use only non-NA, non-empty string categories
                split.categories <- current_split_categories[!is.na(current_split_categories) & current_split_categories != ""]
                if (length(split.categories) == 0) split.categories <- NULL # Reset if no valid splits found
            }

            # Collect traces for this facet (handling both many and one member data if present)
            traces <- list()
            if (!is.null(data.for.this.facet.many) && nrow(data.for.this.facet.many) > 0) {
                # Pass split.by value itself, not the categories
                traces <- append(traces, collect.traces.for.facet(split.categories, data.for.this.facet.many, split.by, "groupid", marker.type, current.facet))
            }
            # TODO: Add handling for df.sim.groupids.one.member (geom_point equivalent) if needed
            # if (!is.null(data.for.this.facet.one) && nrow(data.for.this.facet.one) > 0) {
            #    # Add point traces similar to how geom_point was used in ggplot
            # }

            fig$data <- append(fig$data, traces)
        }
    } # End of df.sim traces processing

    if (plotly.debug) {
        cat("\nDATA\n\n")
        # browser()
    }

    # DATA ELEMENTS
    if (!is.null(df.truth)) {
        marker.type <- "marker"

        # Add marker shape/color info if df.truth exists
        if (!is.null(df.truth) && nrow(df.truth) > 0) {
            # Ensure shape.data.by and color.data.by exist before using them
            if (!"shape.data.by" %in% names(df.truth)) df.truth$shape.data.by <- ""
            if (!"color.data.by" %in% names(df.truth)) df.truth$color.data.by <- ""

            df.truth$marker.shapes <- unlist(lapply(df.truth$shape.data.by, function(val) {
                # Default shape if val is invalid or mapping missing
                if (is.null(val) || is.na(val) || val == "" || is.null(marker.mappings[[val]])) "circle" else marker.mappings[[val]]
            }))
            df.truth$marker.colors <- unlist(lapply(df.truth$color.data.by, function(val) {
                # Default color if val is invalid or mapping missing
                if (is.null(val) || is.na(val) || val == "" || is.null(color.data.primary.colors[[val]])) "#000000" else color.data.primary.colors[[val]]
            }))
        }


        # Iterate through the combined facet categories
        for (facet_index in seq_along(facet.categories)) {
            fac.cat <- facet.categories[facet_index]
            current.facet <- facet_index # Use index for axis mapping

            # Subset data for the current combined facet
            data.for.this.facet <- NULL
            if (!is.null(df.truth) && nrow(df.truth) > 0) {
                data.for.this.facet <- subset(
                    df.truth,
                    as.character(df.truth[[combined_facet_col]]) == as.character(fac.cat) # Ensure comparison works with factors
                )
            }

            # Check if there's any data for this facet
            if (is.null(data.for.this.facet) || nrow(data.for.this.facet) == 0) {
                next # Skip to next facet if no data
            }

            # Determine split categories *within this facet*
            split.categories <- NULL
            # Use 'stratum' as the split column for truth data as per prepare.plot logic
            # Ensure 'stratum' column exists and split.by is set
            if (!is.null(split.by) && "stratum" %in% names(data.for.this.facet)) {
                current_split_categories <- unique(as.character(data.for.this.facet[["stratum"]]))
                split.categories <- current_split_categories[!is.na(current_split_categories) & current_split_categories != ""]
                if (length(split.categories) == 0) split.categories <- NULL
            }

            # Collect traces for this facet
            # Use 'stratum' as the trace identifier column for truth data points if it exists, otherwise maybe color.data.by?
            # Need a reliable column to group points within the facet. 'stratum' seems intended.
            trace_group_col <- if ("stratum" %in% names(data.for.this.facet)) "stratum" else "color.data.by" # Fallback, might need adjustment
            # Ensure the trace_group_col actually exists
            if (!trace_group_col %in% names(data.for.this.facet)) {
                warning(paste("Trace grouping column", trace_group_col, "not found for truth data in facet", fac.cat))
                next # Skip facet if no way to group traces
            }
            # Pass split.by value itself, not the categories
            traces <- collect.traces.for.facet(split.categories, data.for.this.facet, "stratum", trace_group_col, marker.type, current.facet)
            fig$data <- append(fig$data, traces)
        }
    } # End of df.truth processing

    # browser()
    # LAYOUT
    # At this point we have processed all the traces and now need to lay them out

    # How many figures do we need? One for each facet.
    if (figure.count > 1) {
        # Use n.facet.rows if provided and valid, otherwise calculate based on figure count
        if (!is.null(n.facet.rows) && is.numeric(n.facet.rows) && n.facet.rows > 0) {
            plot.rows <- ceiling(n.facet.rows)
            figures.per.row <- ceiling(figure.count / plot.rows)
        } else {
            # Default layout calculation
            figures.per.row <- ceiling(sqrt(figure.count))
            plot.rows <- ceiling(figure.count / figures.per.row)
        }


        fig$layout$grid <- list(rows = plot.rows, columns = figures.per.row, pattern = "independent")
        # fig$layout$annotations <- list() # Moved initialization earlier

        # Re-introduce row/column tracking for annotation positioning
        current_row <- 1
        current_col <- 1

        for (i in 1:figure.count) {
            # Assign axes based on index (x, y for i=1, x2, y2 for i=2, etc.)
            xaxis_name <- if (i == 1) "xaxis" else paste0("xaxis", i)
            yaxis_name <- if (i == 1) "yaxis" else paste0("yaxis", i)
            xaxis_ref <- if (i == 1) "x" else paste0("x", i)
            yaxis_ref <- if (i == 1) "y" else paste0("y", i)

            # Set axis titles and apply global year range (domains are handled by the grid)
            xaxis_definition <- list(title = list(text = "Years", standoff = 5), anchor = yaxis_ref, automargin = TRUE) # Revert automargin
            if (!is.null(global_year_range)) {
                xaxis_definition$range <- global_year_range
            }
            fig$layout[[xaxis_name]] <- xaxis_definition

            # Ensure y.axis.labels exists and has enough elements
            y_axis_title <- if (!is.null(fig$y.axis.labels) && length(fig$y.axis.labels) >= i) fig$y.axis.labels[i] else ""
            fig$layout[[yaxis_name]] <- list(title = list(text = y_axis_title, standoff = 10), anchor = xaxis_ref, automargin = TRUE) # Revert automargin

            # Add annotations (facet titles), referencing the correct axes
            # Ensure facet.categories exists and has enough elements
            annotation_text <- if (!is.null(facet.categories) && length(facet.categories) >= i) facet.categories[i] else "" # Restore original text
            # annotation_text <- paste("Facet", i) # DEBUG: Use simple placeholder text
            fig$layout$annotations <- append(fig$layout$annotations, list(list(
                text = annotation_text,
                showarrow = FALSE,
                xref = xaxis_ref, # Reference the axis ID for x positioning
                yref = yaxis_ref, # Reference the axis ID for y positioning
                x = 0.5, # Center the text relative to the subplot's x-axis domain
                y = 1.05, # Position slightly above the top of the y-axis domain (reverted)
                xanchor = "center",
                yanchor = "bottom", # Anchor the bottom of the text at the specified y coordinate
                font = list(
                    size = 12 # Slightly smaller font for facet titles
                )
            )))

            # Update row/column tracking for next annotation's y calculation
            if (current_col == figures.per.row) {
                current_col <- 1
                current_row <- current_row + 1
            } else {
                current_col <- current_col + 1
            }
        }
        # Add overall plot title if needed (might interfere with facet titles)
        # fig$layout$title <- list(text = plot.title, y = 0.98) # Adjust y position if using annotations
    } else if (figure.count == 1) { # Single plot (no faceting or only one facet category)
        # browser()
        # Use default xaxis/yaxis and apply global range
        y_axis_title_single <- if (!is.null(fig$y.axis.labels) && length(fig$y.axis.labels) >= 1) fig$y.axis.labels[1] else ""
        xaxis_definition_single <- list(title = "Years", anchor = "y")
        if (!is.null(global_year_range)) {
            xaxis_definition_single$range <- global_year_range
        }
        fig$layout[["xaxis"]] <- xaxis_definition_single
        fig$layout[["yaxis"]] <- list(title = y_axis_title_single, anchor = "x")
        # Add title for single plot
        fig$layout$title <- list(text = plot.title) # Set main title only for single plot case
    } else {
        # No figures to plot (e.g., empty data)
        # Return an empty plot or a message?
        fig$layout$title <- list(text = "No data to display")
        fig$layout$xaxis <- list(visible = FALSE)
        fig$layout$yaxis <- list(visible = FALSE)
    }

    # Legend settings
    fig$layout$legend <- list(
        traceorder = "normal", # Keep legend order same as trace order
        itemsizing = "constant", # Prevent legend items from resizing
        orientation = "h", # Horizontal orientation
        yanchor = "top", # Anchor legend top
        y = -0.1, # Position below plot area (adjust as needed)
        xanchor = "center", # Center legend horizontally
        x = 0.5 # Center position
    )
    if (hide.legend) {
        fig$layout$showlegend <- FALSE
    }

    # Add top margin to make space for annotations
    fig$layout$margin <- list(t = 50) # Adjust 't' value (top margin in pixels) if needed


    # browser()
    # print(str(fig$layout$annotations)) # DEBUG removed
    # print(fig)
    # Return the final plot object
    # Use tryCatch to handle potential errors during build, especially with complex layouts/data
    final_plot <- tryCatch(
        {
            plotly_build(fig)
        },
        error = function(e) {
            warning("Error building plotly figure: ", e$message)
            # Return a minimal plot with error message
            plotly::plot_ly() %>% plotly::layout(title = paste("Plotting Error:", e$message))
        }
    )

    return(final_plot)
}
