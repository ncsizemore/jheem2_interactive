# Local copy of Plotly plotting functions from jheem2 package for debugging

# execute.plotly.plot function definition (copied from user input)
execute.plotly.plot <- function(prepared.plot.data,
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
    y.label <- prepared.plot.data$details$y.label
    plot.title <- prepared.plot.data$details$plot.title
    # Ensure outcome.metadata is accessed correctly from details
    outcome.metadata <- prepared.plot.data$details$outcome.metadata.list # Adjusted based on prepare.plot output structure

    #-- PREPARE PLOT COLORS, SHADES, SHAPES, ETC. --#

    if (!is.null(df.sim)) {
        df.sim["linetype.sim.by"] <- df.sim[style.manager$linetype.sim.by]
        df.sim["shape.sim.by"] <- df.sim[style.manager$shape.sim.by]
        df.sim["color.sim.by"] <- df.sim[style.manager$color.sim.by]
    }


    if (!is.null(df.truth)) {
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

    sim.color.groups <- sort(unique(df.sim$color.sim.by))
    data.color.groups <- sort(unique(df.truth$color.data.by))
    # browser()

    # if coloring by the same thing, use the same palette (defaulting to SIM's palette) unless one is missing
    if (style.manager$color.sim.by == style.manager$color.data.by) {
        # browser()
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

    ## RIBBON COLOR
    color.ribbon.by <- NULL
    if (!is.null(df.sim)) {
        # Use ggplot2::alpha for consistency, though Plotly uses rgba strings
        alpha_val <- style.manager$alpha.ribbon %||% 0.2 # Default alpha if not set
        # Convert hex colors to rgba strings for Plotly fillcolor
        color.ribbon.by <- sapply(colors.for.sim, function(hex_color) {
            rgb_val <- grDevices::col2rgb(hex_color)
            paste0("rgba(", rgb_val[1], ",", rgb_val[2], ",", rgb_val[3], ",", alpha_val, ")")
        })
        names(color.ribbon.by) <- names(colors.for.sim) # Ensure names are preserved
    }


    ## SHADES FOR DATA
    color.data.shaded.colors <- NULL
    if (!is.null(df.truth)) {
        color.data.shaded.colors <- unlist(lapply(color.data.primary.colors, function(prim.color) {
            style.manager$get.shades(base.color = prim.color, length(unique(df.truth$shade.data.by)))
        }))
        # This can lead to problems if we have either of these being "" because then we'll get an underscore that won't match the actual column values in the data frame
        if (identical(unique(df.truth$color.data.by), "")) {
            names(color.data.shaded.colors) <- unique(df.truth$shade.data.by)
        } else {
            names(color.data.shaded.colors) <- do.call(paste, c(expand.grid(unique(df.truth$shade.data.by), unique(df.truth$color.data.by)), list(sep = "__")))
        }
    }

    ## SHAPES
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

    ## LINETYPES
    linetypes.for.sim <- NULL
    if (!is.null(df.sim)) {
        linetypes.for.sim <- style.manager$get.linetypes(length(unique(df.sim$linetype.sim.by)))
        names(linetypes.for.sim) <- unique(df.sim$linetype.sim.by)
    }

    ## GROUPS
    # break df.sim into two data frames, one for outcomes where the sim will be lines and the other for where it will be points
    df.sim.groupids.one.member <- NULL
    df.sim.groupids.many.members <- NULL
    if (!is.null(df.sim)) {
        groupids.with.one.member <- setdiff(unique(df.sim$groupid), df.sim$groupid[which(duplicated(df.sim$groupid))])
        df.sim$groupid_has_one_member <- with(df.sim, groupid %in% groupids.with.one.member)
        df.sim.groupids.one.member <- subset(df.sim, groupid_has_one_member)
        df.sim.groupids.many.members <- subset(df.sim, !groupid_has_one_member)
    }
    # PLOTLY PLOTS

    plotly.debug <- FALSE
    # Plotly uses 'dash' instead of 'dashed' for dashed lines, so
    # convert the value in linetypes.for.sim
    linetypes.for.sim <- gsub("dashed", "dash", linetypes.for.sim)
    # Mapping the ggplot marker shapes into plotly
    marker.mappings <- unlist(lapply(shapes.for.data, function(gg_shape) {
        # Ensure gg_shape is treated as numeric if it's not already
        gg_shape_num <- as.numeric(gg_shape)
        if (is.na(gg_shape_num)) {
            return("circle")
        } # Default if conversion fails

        if (gg_shape_num == 21) {
            return("circle")
        } # Circle
        if (gg_shape_num == 22) {
            return("square")
        } # Square
        if (gg_shape_num == 23) {
            return("diamond")
        } # Diamond
        if (gg_shape_num == 24) {
            return("triangle-up")
        } # Triangle UP (Plotly uses triangle-up)
        if (gg_shape_num == 25) {
            return("triangle-down")
        } # Triangle DOWN (Plotly uses triangle-down)
        return("circle") # Default shape
    }))
    # Ensure names are preserved if shapes.for.data had names
    if (!is.null(names(shapes.for.data))) {
        names(marker.mappings) <- names(shapes.for.data)
    }


    sim.trace.count <- 0
    trace.in.legend <- list()

    build.marker.traces <- function(trace.data, base.trace, clean.group.id) {
        unique.shapes <- unique(trace.data$marker.shapes)

        # Main marker traces by shape
        marker.traces <- lapply(unique.shapes, function(shape) {
            shape.data <- subset(trace.data, marker.shapes == shape)

            # Use marker.colors column directly
            col <- shape.data$marker.colors[1] %||% "#000000" # Default to black if missing

            sym <- shape # Use the shape directly from unique.shapes

            trace <- base.trace
            trace$showlegend <- FALSE
            trace$x <- shape.data$year
            trace$y <- shape.data$value

            trace[["marker"]] <- list(
                color = col, # Use the color from the data
                symbol = sym,
                line = list(
                    color = "#202020", # Border color
                    width = 1
                )
            )

            return(trace)
        })

        # Shape legend traces (simplified - maybe just show one example per shape?)
        shape.traces <- lapply(unique(trace.data$marker.shapes), function(working.symbol) {
            shape.key.val <- paste0("marker_shape_", working.symbol)
            shape.name <- names(marker.mappings)[marker.mappings == working.symbol][1] %||% working.symbol # Get original name if possible

            if (is.null(trace.in.legend[[shape.key.val]])) {
                shape.trace <- list(
                    type = "scatter",
                    mode = "markers",
                    x = list(NULL), # No data points
                    y = list(NULL),
                    name = shape.name, # Use original name for legend
                    legendgroup = "Shapes", # Group shape legends
                    marker = list(
                        color = "grey", # Use a neutral color
                        symbol = working.symbol,
                        line = list(color = "#202020", width = 1)
                    )
                )

                if (!hide.legend) {
                    trace.in.legend[[shape.key.val]] <<- TRUE
                } else {
                    shape.trace$showlegend <- FALSE
                    trace.in.legend[[shape.key.val]] <<- FALSE # Explicitly set to false if hidden
                }

                return(shape.trace)
            }
            return(NULL)
        })


        # Color legend traces (simplified - maybe just one example per color?)
        color.traces <- lapply(unique(trace.data$marker.colors), function(working.color) {
            color.key.val <- paste0("marker_color_", working.color)
            color.name <- names(color.data.primary.colors)[color.data.primary.colors == working.color][1] %||% working.color # Get original name

            if (is.null(trace.in.legend[[color.key.val]])) {
                color.trace <- list(
                    type = "scatter",
                    mode = "markers",
                    x = list(NULL),
                    y = list(NULL),
                    name = color.name, # Use original name for legend
                    legendgroup = "Colors", # Group color legends
                    marker = list(
                        color = working.color,
                        symbol = "circle", # Use a standard symbol
                        line = list(color = "#202020", width = 1)
                    )
                )

                if (!hide.legend) {
                    trace.in.legend[[color.key.val]] <<- TRUE
                } else {
                    color.trace$showlegend <- FALSE
                    trace.in.legend[[color.key.val]] <<- FALSE # Explicitly set to false if hidden
                }
                return(color.trace)
            }
            return(NULL)
        })


        # Combine all traces and remove NULLs
        all.traces <- c(marker.traces, shape.traces, color.traces)
        clean.traces <- Filter(Negate(is.null), all.traces)
        return(clean.traces)
    }


    inner.collector <- function(cat.list,
                                data.for.this.facet,
                                trace.column,
                                marker.type,
                                current.facet) {
        trace.list <- list() # Collects all output traces

        for (trace_id in cat.list) {
            # Ensure trace_id is treated as character for subsetting if it's factor
            trace_id_char <- as.character(trace_id)
            trace.data <- subset(
                data.for.this.facet,
                as.character(data.for.this.facet[[trace.column]]) == trace_id_char
            )

            # Skip if no data for this trace_id
            if (nrow(trace.data) == 0) next

            clean.group.id <- trace_id_char # Use character version
            is.ribbon <- "value.upper" %in% names(trace.data) && "value.lower" %in% names(trace.data) && summary.type != "individual.simulation"

            if (is.ribbon) {
                # message("Ribbon Trace data found")
                # browser()
                # Find the correct fill color based on the group name (trace_id)
                # Match trace_id against the names of color.ribbon.by
                matching_color_name <- names(color.ribbon.by)[sapply(names(color.ribbon.by), function(nm) grepl(paste0("^", nm, "$"), trace_id_char))] # Exact match needed
                fill_color <- color.ribbon.by[matching_color_name[1]] %||% "rgba(128,128,128,0.2)" # Default grey ribbon

                # Ensure x and y are sorted by year for ribbon
                trace.data <- trace.data[order(trace.data$year), ]

                # Create combined x and y for ribbon shape (upper then reversed lower)
                ribbon_x <- c(trace.data$year, rev(trace.data$year))
                ribbon_y <- c(trace.data$value.upper, rev(trace.data$value.lower))

                ribbon.trace <- list(
                    type = "scatter",
                    mode = "lines",
                    name = paste0(clean.group.id, " Interval"),
                    x = ribbon_x,
                    y = ribbon_y,
                    xaxis = paste0("x", current.facet),
                    yaxis = paste0("y", current.facet),
                    line = list(width = 0), # No border line for the ribbon itself
                    fill = "toself", # Fill the shape defined by the points
                    fillcolor = fill_color,
                    legendgroup = clean.group.id, # Group ribbon with its line
                    showlegend = FALSE, # Don't show ribbon in legend separately
                    hoverinfo = "skip"
                )
                trace.list <- append(trace.list, list(ribbon.trace))
            }


            # Core base trace
            base.trace <- list(
                type = "scatter",
                mode = paste0(marker.type, "s"), # 'lines' or 'markers'
                name = clean.group.id,
                x = trace.data$year,
                y = trace.data$value,
                xaxis = paste0("x", current.facet),
                yaxis = paste0("y", current.facet),
                legendgroup = clean.group.id # Group line/markers together
            )

            if (marker.type == "line") {
                # Line style logic
                sim.trace.count <<- sim.trace.count + 1
                # Use line.color and line.shape columns directly if they exist
                col <- trace.data$line.color[1] %||% colors.for.sim[trace_id_char] %||% "#000000" # Default black
                mark <- trace.data$line.shape[1] %||% linetypes.for.sim[trace_id_char] %||% "solid" # Default solid

                # Legend handling
                trace.key <- paste0(col, mark, clean.group.id) # Make key more specific
                if (!hide.legend) {
                    if (!is.null(trace.in.legend[[trace.key]])) {
                        base.trace$showlegend <- FALSE
                    } else {
                        trace.in.legend[[trace.key]] <<- TRUE
                        base.trace$showlegend <- TRUE # Explicitly show if first time
                    }
                } else {
                    base.trace$showlegend <- FALSE
                }


                base.trace[["line"]] <- list(dash = mark, color = col)
                trace.list <- append(trace.list, list(base.trace))
            } else if (marker.type == "marker") {
                # Ensure marker columns exist before calling build.marker.traces
                if (!"marker.shapes" %in% names(trace.data) || !"marker.colors" %in% names(trace.data)) {
                    warning(paste("Missing marker shape/color columns for trace:", trace_id_char))
                    # Add a basic marker trace as fallback?
                    base.trace$showlegend <- FALSE # Hide potentially incorrect legend items
                    trace.list <- append(trace.list, list(base.trace))
                } else {
                    marker.traces <- build.marker.traces(trace.data, base.trace, clean.group.id)
                    trace.list <- append(trace.list, marker.traces)
                }
            }
        } # End loop through cat.list

        return(trace.list)
    }



    collect.traces.for.facet <- function(split.categories,
                                         data.for.this.facet,
                                         local.split.by,
                                         trace.column,
                                         marker.type,
                                         current.facet) {
        rv <- list()
        if (is.null(local.split.by) || is.null(split.categories)) {
            # No splits or categories provided, treat as single group
            category.list <- unique(data.for.this.facet[[trace.column]])
            raw.traces <- inner.collector(
                category.list,
                data.for.this.facet,
                trace.column,
                marker.type,
                current.facet
            )
            rv <- append(rv, raw.traces)
        } else {
            # There are splits to collect
            for (spl.cat in split.categories) {
                # Ensure spl.cat is character for subsetting if factor
                spl.cat_char <- as.character(spl.cat)
                data.for.this.split <- subset(
                    data.for.this.facet,
                    as.character(data.for.this.facet[[local.split.by]]) == spl.cat_char
                )

                if (nrow(data.for.this.split) > 0) {
                    # One trace for each category within the split
                    category.list <- unique(data.for.this.split[[trace.column]])
                    raw.traces <- inner.collector(
                        category.list,
                        data.for.this.split, # Use data filtered for this split
                        trace.column, marker.type,
                        current.facet
                    )
                    rv <- append(rv, raw.traces)
                }
            } # End of splits
        }
        rv
    }


    # Helper for properly creating the y.axis labels for the figures
    y.axis.label.helper <- function(outcome.metadata, outcome) {
        # Ensure outcome is character and exists in metadata names
        outcome_char <- as.character(outcome)
        if (!outcome_char %in% names(outcome.metadata)) {
            warning(paste("Outcome", outcome_char, "not found in outcome metadata."))
            return(outcome_char) # Return outcome name as fallback
        }
        meta <- outcome.metadata[[outcome_char]]
        label <- meta$axis.name %||% outcome_char # Use outcome name if axis.name is missing
        unit <- meta$units %||% "" # Default to empty string if units missing

        # We want to prevent a 'Cases (cases)' situation here
        if (tolower(label) == tolower(unit) || unit == "") {
            return(label)
        }
        return(paste0(label, " (", unit, ")"))
    }
    # Draw the plots

    # Define the list structure
    # Initialize the plotly object as a list
    fig <- list(data = list(), layout = list())


    # Add labels for the y-axis and a title for the plot
    fig$layout$title <- list(text = plot.title)

    # Each figure will need a y axis label, but that will be determined by the outcome,
    # So we should have a vector of y axis labels that the layout can use when laying
    # out the plot
    y.axis.labels <- c()

    # Remove alpha guide (no direct equivalent in Plotly)
    # Nothing to do for alpha guides since they don’t exist in Plotly

    # if (!plot.year.lag.ratio) {
    #     # Set y-axis limits and format labels with commas
    #     rv$layout$yaxis <- modifyList(rv$layout$yaxis, list(range = c(0, NULL), tickformat = ","))
    # } else {
    #     # Format y-axis labels with commas
    #     rv$layout$yaxis <- modifyList(rv$layout$yaxis, list(tickformat = ","))
    # }

    # This will be changed if facet.by is set, but set it to 1 initially
    figure.count <- 1
    facet.categories <- NULL
    # figures.per.row = 3

    # Determine facetting columns and categories
    facet.cols <- character(0)
    if (!is.null(facet.by)) {
        facet.cols <- paste0("facet.by", seq_along(facet.by))
        # Check if these columns exist in df.sim or df.truth
        if (!all(facet.cols %in% names(df.sim %||% data.frame())) && !all(facet.cols %in% names(df.truth %||% data.frame()))) {
            warning("Facet columns not found in data, defaulting to outcome faceting.")
            facet.cols <- "outcome.display.name"
        }
    } else {
        facet.cols <- "outcome.display.name" # Default facet by outcome display name
    }

    # Combine data for determining facets if necessary
    combined_facet_data <- NULL
    if (!is.null(df.sim) && all(facet.cols %in% names(df.sim))) {
        combined_facet_data <- unique(df.sim[, facet.cols, drop = FALSE])
    }
    if (!is.null(df.truth) && all(facet.cols %in% names(df.truth))) {
        truth_facets <- unique(df.truth[, facet.cols, drop = FALSE])
        combined_facet_data <- rbind(combined_facet_data, truth_facets)
        combined_facet_data <- unique(combined_facet_data)
    }

    if (is.null(combined_facet_data) || nrow(combined_facet_data) == 0) {
        warning("No data found for faceting.")
        # Potentially return an empty plot or message
        return(plotly::plot_ly())
    }

    # Order facets if possible (e.g., alphabetically)
    combined_facet_data <- combined_facet_data[do.call(order, combined_facet_data), , drop = FALSE]
    facet.categories <- combined_facet_data
    figure.count <- nrow(facet.categories)


    # SIMULATION ELEMENTS
    if (!is.null(df.sim)) {
        marker.type <- "line"
        if (plotly.debug) cat("SIM\n\n")

        # Pre-assign colors/shapes to df.sim if not already done by prepare.plot logic
        if (!"line.color" %in% names(df.sim.groupids.many.members)) {
            df.sim.groupids.many.members$line.color <- unlist(lapply(as.character(df.sim.groupids.many.members$color.sim.by), function(val) colors.for.sim[val] %||% "#000000"))
        }
        if (!"line.shape" %in% names(df.sim.groupids.many.members)) {
            df.sim.groupids.many.members$line.shape <- unlist(lapply(as.character(df.sim.groupids.many.members$linetype.sim.by), function(val) linetypes.for.sim[val] %||% "solid"))
        }
        # Same for one.member df if needed

        current.facet <- 1
        for (i in 1:figure.count) {
            facet_row <- facet.categories[i, , drop = FALSE]
            # Filter data for the current facet combination
            data.for.this.facet.sim <- df.sim
            for (col_name in names(facet_row)) {
                data.for.this.facet.sim <- subset(data.for.this.facet.sim, data.for.this.facet.sim[[col_name]] == facet_row[[col_name]])
            }

            if (nrow(data.for.this.facet.sim) > 0) {
                split.categories.sim <- if (!is.null(split.by)) unique(data.for.this.facet.sim[[split.by]]) else NULL
                traces <- collect.traces.for.facet(
                    split.categories.sim,
                    data.for.this.facet.sim,
                    split.by, # Pass the actual split.by column name
                    "groupid", # Trace groups within split are identified by groupid
                    marker.type,
                    current.facet
                )
                fig$data <- append(fig$data, traces)
            }
            current.facet <- current.facet + 1
        }
    } # End of df.sim traces


    if (plotly.debug) cat("\nDATA\n\n")

    # DATA ELEMENTS
    if (!is.null(df.truth)) {
        marker.type <- "marker"

        # Pre-assign marker shapes/colors
        if (!"marker.shapes" %in% names(df.truth)) {
            df.truth$marker.shapes <- unlist(lapply(as.character(df.truth$shape.data.by), function(val) marker.mappings[val] %||% "circle"))
        }
        if (!"marker.colors" %in% names(df.truth)) {
            # Use color.and.shade.data.by for color lookup? Or just color.data.by?
            # Assuming color.data.shaded.colors maps color.and.shade.data.by
            df.truth$marker.colors <- unlist(lapply(as.character(df.truth$color.and.shade.data.by), function(val) color.data.shaded.colors[val] %||% "#000000"))
        }

        current.facet <- 1
        for (i in 1:figure.count) {
            facet_row <- facet.categories[i, , drop = FALSE]
            # Filter data for the current facet combination
            data.for.this.facet.truth <- df.truth
            for (col_name in names(facet_row)) {
                data.for.this.facet.truth <- subset(data.for.this.facet.truth, data.for.this.facet.truth[[col_name]] == facet_row[[col_name]])
            }

            if (nrow(data.for.this.facet.truth) > 0) {
                split.categories.truth <- if (!is.null(split.by)) unique(data.for.this.facet.truth[[split.by]]) else NULL
                # What defines unique traces for data points? Maybe 'source' or 'color.and.shade.data.by'?
                # Using 'color.and.shade.data.by' as the trace identifier within splits
                traces <- collect.traces.for.facet(
                    split.categories.truth,
                    data.for.this.facet.truth,
                    split.by, # Pass the actual split.by column name
                    "color.and.shade.data.by", # Unique data traces identified by this
                    marker.type,
                    current.facet
                )
                fig$data <- append(fig$data, traces)
            }
            current.facet <- current.facet + 1
        }
    } # End of df.truth traces


    # LAYOUT
    if (figure.count > 0) {
        figures.per.row <- n.facet.rows # Use provided n.facet.rows if available
        if (is.null(figures.per.row) || figures.per.row <= 0) {
            figures.per.row <- ceiling(sqrt(figure.count)) # Default square-ish layout
        }
        plot.rows <- ceiling(figure.count / figures.per.row)
        plot.cols <- figures.per.row

        fig$layout$grid <- list(rows = plot.rows, columns = plot.cols, pattern = "independent")
        fig$layout$annotations <- list()

        # Determine y-axis labels for each facet
        fig$layout$yaxis_labels <- character(figure.count)
        for (i in 1:figure.count) {
            facet_row <- facet.categories[i, , drop = FALSE]
            # Find the outcome name associated with this facet
            # Assuming 'outcome.display.name' is always the primary or only facet column
            outcome_name_for_facet <- facet_row$outcome.display.name[1]
            # Find the original outcome id corresponding to the display name
            original_outcome_id <- names(outcome.metadata)[sapply(outcome.metadata, function(meta) meta$display.name == outcome_name_for_facet)][1] %||% outcome_name_for_facet

            fig$layout$yaxis_labels[i] <- y.axis.label.helper(outcome.metadata, original_outcome_id)
        }


        # Layout constants
        x_padding <- 0.02
        y_padding <- 0.04
        title_y_offset <- 0.05 # Space for subplot titles

        x_domain_width <- (1 - (plot.cols + 1) * x_padding) / plot.cols
        y_domain_height <- (1 - (plot.rows + 1) * y_padding - title_y_offset) / plot.rows # Adjust for titles

        current_row <- 1
        current_col <- 1

        for (i in 1:figure.count) {
            # Calculate domain based on current row and column (Plotly grid is 1-based from bottom-left)
            x_start <- (current_col - 1) * (x_domain_width + x_padding) + x_padding
            x_end <- x_start + x_domain_width

            y_start <- (plot.rows - current_row) * (y_domain_height + y_padding) + y_padding # Y domain from bottom up
            y_end <- y_start + y_domain_height

            xaxis_name <- paste0("xaxis", i)
            yaxis_name <- paste0("yaxis", i)

            fig$layout[[xaxis_name]] <- list(title = list(text = "Year", standoff = 5), domain = c(x_start, x_end), anchor = yaxis_name, automargin = TRUE)
            fig$layout[[yaxis_name]] <- list(title = list(text = fig$layout$yaxis_labels[i], standoff = 10), domain = c(y_start, y_end), anchor = xaxis_name, automargin = TRUE)

            # Add subplot title annotation
            facet_title_parts <- as.character(unlist(facet.categories[i, , drop = TRUE]))
            facet_title <- paste(facet_title_parts, collapse = " - ")

            fig$layout$annotations <- append(fig$layout$annotations, list(list(
                text = facet_title,
                showarrow = FALSE,
                xref = "paper", # Relative to subplot area
                yref = "paper",
                x = x_start + x_domain_width / 2, # Center above subplot
                y = y_end + y_padding / 2, # Position above subplot
                xanchor = "center",
                yanchor = "bottom",
                font = list(size = 12)
            )))

            # Move to next grid position
            current_col <- current_col + 1
            if (current_col > plot.cols) {
                current_col <- 1
                current_row <- current_row + 1
            }
        }
        # Remove temporary label storage
        fig$layout$yaxis_labels <- NULL
    } else {
        # No facets, single plot layout
        fig$layout[["xaxis"]] <- list(title = "Year", anchor = "y1")
        fig$layout[["yaxis"]] <- list(title = y.axis.label.helper(outcome.metadata, outcomes[1]), anchor = "x1")
    }

    # Add general layout settings
    fig$layout$hovermode <- "closest"
    fig$layout$legend <- list(traceorder = "grouped", groupclick = "toggleitem") # Group legend items

    # Return the final plot object
    # Use plotly::plot_ly to build from the list structure
    # Need to ensure plotly library is loaded
    if (!requireNamespace("plotly", quietly = TRUE)) {
        stop("Plotly package needed for this function to work. Please install it.", call. = FALSE)
    }

    # Create the plot using plot_ly and add traces iteratively
    p <- plotly::plot_ly()
    for (trace in fig$data) {
        # Add trace type if missing (should be scatter)
        trace$type <- trace$type %||% "scatter"
        p <- plotly::add_trace(p, !!!trace) # Use !!! to splice list arguments
    }

    # Apply layout
    p <- plotly::layout(p, !!!fig$layout)

    return(p)
}


# plot.simulations function definition (copied from user input)
plot.simulations <- function(...,
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
                             interval.coverate = 0.95, # Note: This parameter is not used in execute.plotly.plot
                             data.manager = get.default.data.manager(),
                             # style.manager = get.default.style.manager('plotly'), # Use default for now
                             style.manager = get.default.style.manager(),
                             hide.legend = FALSE) {
    plot.which <- "sim.and.data" # Hardcoded as identified

    # Use match.call to handle ... correctly
    simset.args <- list(...)
    deparsed.args <- match.call(expand.dots = FALSE)$...

    # Validation step
    # Need plot.data.validation function available or copied here
    if (!exists("plot.data.validation") || !is.function(plot.data.validation)) {
        stop("plot.data.validation function is required but not found.")
    }
    if (!exists("prepare.plot") || !is.function(prepare.plot)) {
        stop("prepare.plot function is required but not found.")
    }
    if (!exists("get.default.data.manager") || !is.function(get.default.data.manager)) {
        stop("get.default.data.manager function is required but not found.")
    }
    if (!exists("get.default.style.manager") || !is.function(get.default.style.manager)) {
        stop("get.default.style.manager function is required but not found.")
    }


    plot.data <- plot.data.validation(
        simset.args,
        deparsed.args,
        outcomes,
        corresponding.data.outcomes,
        plot.which,
        summary.type
    )

    # These values are possibly modified by the plot.data.validation call, so
    # they need to be extracted from the returned list.
    simset.list <- plot.data$simset.list
    outcomes <- plot.data$outcomes

    # Data preparation step
    prepared.plot.data <- prepare.plot(simset.list,
        outcomes = outcomes,
        locations = NULL, # prepare.plot expects locations for data.only
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
        style.manager = style.manager, # Pass style manager to prepare.plot
        debug = F
    ) # Assuming debug=F

    # Execution step
    execute.plotly.plot(prepared.plot.data,
        outcomes = outcomes,
        split.by = split.by,
        facet.by = facet.by,
        plot.which = plot.which,
        summary.type = summary.type,
        plot.year.lag.ratio = plot.year.lag.ratio,
        n.facet.rows = n.facet.rows,
        style.manager = style.manager,
        debug = debug, # Pass debug flag if needed
        hide.legend = hide.legend
    )
}

# Need definitions for helper functions used within plot.simulations/execute.plotly.plot
# if they are not globally available or part of the jheem2 package namespace
# For example:
# - plot.data.validation
# - prepare.plot
# - get.default.data.manager
# - get.default.style.manager
# - locations::get.location.type (requires 'locations' package)
# - grDevices::col2rgb
# - plotly::plot_ly, plotly::add_trace, plotly::layout

# Placeholder/Reminder: Ensure necessary packages (plotly, locations) are loaded
# and helper functions (plot.data.validation, prepare.plot, etc.) are accessible
# when sourcing this file.
