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
    # Extract data from prepared.plot.data
    df.sim <- prepared.plot.data$df.sim
    df.truth <- prepared.plot.data$df.truth
    y.label <- prepared.plot.data$details$y.label
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

    ## GROUPS (Split sim data for line vs point rendering)
    df.sim.groupids.one.member <- NULL
    df.sim.groupids.many.members <- NULL
    if (!is.null(df.sim)) {
        # Ensure groupid exists
        if (!"groupid" %in% names(df.sim)) {
            df.sim$groupid <- interaction(df.sim$outcome, df.sim$simset, df.sim$sim, df.sim$stratum %||% "", sep = "_")
        }

        groupids.with.one.member <- setdiff(unique(df.sim$groupid), df.sim$groupid[which(duplicated(df.sim$groupid))])
        df.sim$groupid_has_one_member <- with(df.sim, groupid %in% groupids.with.one.member)
        df.sim.groupids.one.member <- subset(df.sim, groupid_has_one_member)
        df.sim.groupids.many.members <- subset(df.sim, !groupid_has_one_member)
    }

    plotly.debug <- FALSE

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
    }

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

    # Legend handling variables
    trace.in.legend <- list()

    # Add line colors/styles to simulation data
    if (!is.null(df.sim.groupids.many.members) && nrow(df.sim.groupids.many.members) > 0) {
        df.sim.groupids.many.members$line.color <-
            unlist(lapply(df.sim.groupids.many.members$color.sim.by, function(val) {
                # Provide default if val is NA, NULL, "", or not in names
                if (is.null(val) || is.na(val) || val == "" || is.null(colors.for.sim[[val]])) {
                    style.manager$get.sim.colors(1)
                } else {
                    colors.for.sim[[val]]
                }
            }))
        df.sim.groupids.many.members$line.shape <-
            unlist(lapply(df.sim.groupids.many.members$linetype.sim.by, function(val) {
                # Provide default if val is NA, NULL, "", or not in names
                if (is.null(val) || is.na(val) || val == "" || is.null(linetypes.for.sim[[val]])) {
                    "solid"
                } else {
                    linetypes.for.sim[[val]]
                }
            }))
    }

    # Add marker shape/color info to truth data
    if (!is.null(df.truth) && nrow(df.truth) > 0) {
        # Ensure shape.data.by and color.data.by exist before using them
        if (!"shape.data.by" %in% names(df.truth)) df.truth$shape.data.by <- ""
        if (!"color.data.by" %in% names(df.truth)) df.truth$color.data.by <- ""

        df.truth$marker.shapes <- unlist(lapply(df.truth$shape.data.by, function(val) {
            # Default shape if val is invalid or mapping missing
            if (is.null(val) || is.na(val) || val == "" || is.null(marker.mappings[[val]])) {
                "circle"
            } else {
                marker.mappings[[val]]
            }
        }))
        df.truth$marker.colors <- unlist(lapply(df.truth$color.data.by, function(val) {
            # Default color if val is invalid or mapping missing
            if (is.null(val) || is.na(val) || val == "" || is.null(color.data.primary.colors[[val]])) {
                "#000000"
            } else {
                color.data.primary.colors[[val]]
            }
        }))
    }

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

    # Apply interaction term to all relevant data frames
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

    # Helper function to extract outcome from facet string
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

    # Create vector of y-axis labels for each facet
    y_axis_labels <- sapply(facet.categories, function(cat) {
        outcome_name <- outcome_from_facet(cat)
        if (!outcome_name %in% names(outcome.metadata)) {
            warning(paste("Outcome", outcome_name, "from facet category not found in outcome.metadata. Using outcome name as label."))
            return(outcome_name) # Use outcome name as fallback label
        }
        y.axis.label.helper(outcome.metadata, outcome_name)
    }, USE.NAMES = TRUE)
    names(y_axis_labels) <- facet.categories

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

    # Helper function for creating a single facet plot with all traces
    create_facet_plot <- function(facet_name, facet_data, truth_data, y_axis_title, hide.legend = FALSE) {
        # Initialize plot with annotations instead of title
        p <- plot_ly() %>%
            layout(
                # Use annotations for the title
                annotations = list(
                    list(
                        text = facet_name,
                        x = 0.5,         # Center horizontally  
                        y = 1.05,        # Slightly above the plot
                        xref = "paper",  # Use paper coordinates
                        yref = "paper",  # Use paper coordinates
                        showarrow = FALSE,
                        font = list(size = 12, weight = "bold"),
                        xanchor = "center",
                        yanchor = "bottom"
                    )
                ),
                xaxis = list(
                    title = list(text = "Years", standoff = 5)
                ),
                yaxis = list(
                    title = list(text = y_axis_title, standoff = 10)
                ),
                margin = list(t = 30, b = 10, l = 50, r = 10)  # Add margin for title space
            )

        # Apply global year range if available
        if (!is.null(global_year_range)) {
            p <- p %>% layout(xaxis = list(range = global_year_range))
        }

        # Process simulation data (with ribbons)
        if (!is.null(facet_data) && nrow(facet_data) > 0) {
            # For each unique group, add traces
            groupids <- unique(facet_data$groupid)

            for (group_id in groupids) {
                # Get data for this group
                group_data <- facet_data[facet_data$groupid == group_id, ]
                if (nrow(group_data) == 0) next

                # Check if this group has ribbon data
                has_ribbon <- "value.upper" %in% names(group_data) &&
                    "value.lower" %in% names(group_data) &&
                    any(!is.na(group_data$value.upper)) &&
                    any(!is.na(group_data$value.lower))

                # Determine visual attributes
                col <- group_data$line.color[1] %||% "#000000"
                linetype <- group_data$line.shape[1] %||% "solid"

                # Add to legend only once per color/linetype combination
                trace.key <- paste(col, linetype, sep = "_")
                show_in_legend <- FALSE
                if (!hide.legend && is.null(trace.in.legend[[trace.key]])) {
                    show_in_legend <- TRUE
                    trace.in.legend[[trace.key]] <<- TRUE
                }

                # Order data by year for ribbon drawing
                group_data <- group_data[order(group_data$year), ]

                # Add ribbon if present
                if (has_ribbon) {
                    # Find ribbon color
                    ribbon_color_name <- group_data$color.sim.by[1]
                    fill_color <- if (!is.null(color.ribbon.by) &&
                        ribbon_color_name %in% names(color.ribbon.by)) {
                        color.ribbon.by[[ribbon_color_name]]
                    } else {
                        "rgba(128,128,128,0.2)" # Default transparent grey
                    }

                    # Add upper bound trace
                    p <- p %>% add_trace(
                        x = group_data$year,
                        y = group_data$value.upper,
                        type = "scatter",
                        mode = "lines",
                        line = list(width = 0),
                        showlegend = FALSE,
                        hoverinfo = "skip",
                        name = paste0(group_id, ".upper")
                    )

                    # Add lower bound trace with fill
                    p <- p %>% add_trace(
                        x = group_data$year,
                        y = group_data$value.lower,
                        type = "scatter",
                        mode = "lines",
                        line = list(width = 0),
                        fill = "tonexty",
                        fillcolor = fill_color,
                        showlegend = FALSE,
                        hoverinfo = "skip",
                        name = paste0(group_id, ".lower")
                    )
                }

                # Add main line trace
                p <- p %>% add_trace(
                    x = group_data$year,
                    y = group_data$value,
                    type = "scatter",
                    mode = "lines",
                    line = list(color = col, dash = linetype),
                    showlegend = show_in_legend,
                    name = group_data$simset[1], # Use simset for legend
                    hoverinfo = "text",
                    text = paste("Year:", group_data$year, "<br>Value:", round(group_data$value, 2))
                )
            }
        }

        # Process truth data (markers)
        if (!is.null(truth_data) && nrow(truth_data) > 0) {
            # Group by shape and color for efficient trace creation
            unique_shapes <- unique(truth_data$marker.shapes)

            for (shape in unique_shapes) {
                shape_data <- truth_data[truth_data$marker.shapes == shape, ]
                unique_colors <- unique(shape_data$marker.colors)

                for (color in unique_colors) {
                    point_data <- shape_data[shape_data$marker.colors == color, ]
                    if (nrow(point_data) == 0) next

                    # Determine if should show in legend
                    marker_key <- paste("truth", color, shape, sep = "_")
                    show_in_legend <- FALSE
                    if (!hide.legend && is.null(trace.in.legend[[marker_key]])) {
                        show_in_legend <- TRUE
                        trace.in.legend[[marker_key]] <<- TRUE
                    }

                    # Add marker trace
                    p <- p %>% add_trace(
                        x = point_data$year,
                        y = point_data$value,
                        type = "scatter",
                        mode = "markers",
                        marker = list(
                            color = color,
                            symbol = shape,
                            line = list(color = "#202020", width = 1)
                        ),
                        showlegend = show_in_legend,
                        name = "Observed Data",
                        hoverinfo = "text",
                        text = paste(
                            "Year:", point_data$year,
                            "<br>Value:", round(point_data$value, 2),
                            if ("data.source" %in% names(point_data)) {
                                paste("<br>Source:", point_data$data.source)
                            } else {
                                ""
                            }
                        )
                    )
                }
            }
        }

        return(p)
    }

    # Create a list to hold individual facet plots
    plot_list <- list()

    # Create a single plot for each facet
    for (facet_name in facet.categories) {
        # Get simulation data for this facet
        sim_data <- NULL
        if (!is.null(df.sim.groupids.many.members) && nrow(df.sim.groupids.many.members) > 0) {
            sim_data <- subset(
                df.sim.groupids.many.members,
                as.character(df.sim.groupids.many.members[[combined_facet_col]]) == as.character(facet_name)
            )
        }

        # Get truth data for this facet
        truth_data <- NULL
        if (!is.null(df.truth) && nrow(df.truth) > 0) {
            truth_data <- subset(
                df.truth,
                as.character(df.truth[[combined_facet_col]]) == as.character(facet_name)
            )
        }

        # Get y-axis title for this facet
        y_axis_title <- y_axis_labels[facet_name]

        # Create the facet plot
        plot_list[[facet_name]] <- create_facet_plot(facet_name, sim_data, truth_data, y_axis_title, hide.legend)
    }

    # Calculate layout grid and create final plot
    if (length(plot_list) > 1) {
        # Calculate grid dimensions
        if (!is.null(n.facet.rows) && is.numeric(n.facet.rows) && n.facet.rows > 0) {
            plot.rows <- ceiling(n.facet.rows)
        } else {
            plot.rows <- ceiling(sqrt(length(plot_list)))
        }
        plot.cols <- ceiling(length(plot_list) / plot.rows)

        # Combine plots with subplot - changed titleX to FALSE to avoid conflicts
        final_plot <- subplot(
            plotlist = plot_list,
            nrows = plot.rows,
            shareX = TRUE,
            shareY = FALSE,
            titleX = FALSE,  # Keep FALSE to avoid title conflicts with annotations
            titleY = TRUE,
            margin = 0.08    # Increased margin between subplots for better title spacing
        ) %>% layout(
            showlegend = !hide.legend,
            legend = list(
                orientation = "h",
                y = -0.1,
                x = 0.5,
                xanchor = "center",
                traceorder = "normal",
                itemsizing = "constant"
            ),
            margin = list(t = 70, b = 80, l = 50, r = 20)  # Increased top margin for facet titles
        )
        
        # Individual plots already have their own annotations
    } else if (length(plot_list) == 1) {
        # If only one plot, just add the main title
        # The plot created by create_facet_plot already has the title as annotation
        final_plot <- plot_list[[1]] %>% layout(
            showlegend = !hide.legend,
            legend = list(
                orientation = "h",
                y = -0.1,
                x = 0.5,
                xanchor = "center",
                traceorder = "normal",
                itemsizing = "constant"
            ),
            margin = list(t = 70, b = 80, l = 50, r = 20)
        )
    } else {
        # No plots - create empty plot with message
        final_plot <- plot_ly() %>% layout(
            title = list(text = "No data to display"),
            xaxis = list(visible = FALSE),
            yaxis = list(visible = FALSE)
        )
    }

    # Print basic info about the plot
    return(final_plot)
}
