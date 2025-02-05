# plotting/simplot/execute_plot.R

#' Execute simulation plot creation
#' @param prepared.plot.data Prepared plot data from prepare_plot
#' @param outcomes Character vector of outcomes being plotted
#' @param split.by Dimension used for splitting
#' @param facet.by Dimensions used for faceting
#' @param plot.which What to plot
#' @param summary.type Type of summary
#' @param plot.year.lag.ratio Whether to plot year lag ratio
#' @param n.facet.rows Number of facet rows
#' @param style.manager Style manager for plot appearance
#' @param debug Debug flag
#' @return ggplot object
execute_plot <- function(prepared.plot.data,
                         outcomes,
                         split.by,
                         facet.by,
                         plot.which,
                         summary.type,
                         plot.year.lag.ratio,
                         n.facet.rows,
                         style.manager,
                         debug) {
    # Unpack prepared data
    df.sim = prepared.plot.data$df.sim
    df.truth = prepared.plot.data$df.truth
    y.label = prepared.plot.data$details$y.label
    
    # Add style information to simulation data
    if (!is.null(df.sim)) {
        df.sim['linetype.sim.by'] = df.sim[style.manager$linetype.sim.by]
        df.sim['shape.sim.by'] = df.sim[style.manager$shape.sim.by]
        df.sim['color.sim.by'] = df.sim[style.manager$color.sim.by]
    }
    
    if (!is.null(df.truth)) {
        # make some other columns
        df.truth['location.type'] = locations::get.location.type(df.truth$location)
        df.truth['shape.data.by'] = df.truth[style.manager$shape.data.by]
        df.truth['color.data.by'] = df.truth[style.manager$color.data.by]
        df.truth['shade.data.by'] = df.truth[style.manager$shade.data.by]
        df.truth['color.and.shade.data.by'] = do.call(paste, c(df.truth['shade.data.by'], df.truth['color.data.by'], list(sep="__")))
    }
    
    #-- STEP 4: PREPARE PLOT COLORS, SHADES, SHAPES, ETC. --#
    
    ## COLORS
    color.sim.by = NULL
    color.data.primary.colors = NULL
    
    sim.color.groups = sort(unique(df.sim$color.sim.by))
    data.color.groups = sort(unique(df.truth$color.data.by))
    
    # if coloring by the same thing, use the same palette (defaulting to SIM's palette) unless one is missing
    if (style.manager$color.sim.by == style.manager$color.data.by) {
        all.color.groups = sort(union(sim.color.groups, data.color.groups))
        
        if (!is.null(df.sim))
            all.colors = style.manager$get.sim.colors(length(all.color.groups))
        else if (!is.null(df.truth))
            all.colors = style.manager$get.data.colors(length(all.color.groups))
        else
            all.colors = NULL # doesn't matter?
        
        names(all.colors) = all.color.groups
        color.sim.by = all.colors[sim.color.groups]
        color.data.primary.colors = all.colors[data.color.groups]
    }
    
    # otherwise, assign colors individually
    else {
        if (!is.null(df.sim)) {
            color.sim.by = style.manager$get.sim.colors(length(sim.color.groups))
            names(color.sim.by) = sim.color.groups
        }
        if (!is.null(df.truth)) {
            color.data.primary.colors = style.manager$get.data.colors(length(data.color.groups))
            names(color.data.primary.colors) = data.color.groups
        }
    }
    
    ## RIBBON COLOR
    color.ribbon.by = NULL
    if (!is.null(df.sim)) {
        color.ribbon.by = ggplot2::alpha(color.sim.by, style.manager$alpha.ribbon)
    }
    
    ## SHADES FOR DATA
    color.data.shaded.colors = NULL
    if (!is.null(df.truth)) {
        color.data.shaded.colors = unlist(lapply(color.data.primary.colors, function(prim.color) {style.manager$get.shades(base.color=prim.color, length(unique(df.truth$shade.data.by)))}))
        names(color.data.shaded.colors) = do.call(paste, c(expand.grid(unique(df.truth$shade.data.by), unique(df.truth$color.data.by)), list(sep="__")))
    }
    
    ## SHAPES
    shapes.for.data = NULL
    shapes.for.sim = NULL
    if (!is.null(df.truth)) {
        shapes.for.data = style.manager$get.shapes(length(unique(df.truth$shape.data.by)))
        names(shapes.for.data) = unique(df.truth$shape.data.by)
    }
    if (!is.null(df.sim)) {
        shapes.for.sim = style.manager$get.shapes(length(unique(df.sim$shape.sim.by)))
        names(shapes.for.sim) = unique(df.sim$shape.sim.by)
    }
    all.shapes.for.scale = c(shapes.for.data, shapes.for.sim)
    
    ## GROUPS
    # break df.sim into two data frames, one for outcomes where the sim will be lines and the other for where it will be points
    if (!is.null(df.sim)) {
        groupids.with.one.member = setdiff(unique(df.sim$groupid), df.sim$groupid[which(duplicated(df.sim$groupid))])
        df.sim$groupid_has_one_member = with(df.sim, groupid %in% groupids.with.one.member)
        df.sim.groupids.one.member = subset(df.sim, groupid_has_one_member)
        df.sim.groupids.many.members = subset(df.sim, !groupid_has_one_member)
    }
    
    
    #-- STEP 5: MAKE THE PLOT --#
    
    rv = ggplot2::ggplot()
    rv = rv + ggplot2::scale_color_manual(name = "sim color", values = color.sim.by)
    rv = rv + ggplot2::scale_shape_manual(name = "data shape", values = all.shapes.for.scale)
    rv = rv + ggplot2::scale_fill_manual(name = "sim color", values = color.sim.by)
    rv = rv + ggplot2::scale_linetype(name="sim linetype")
    
    if (!plot.year.lag.ratio) rv = rv + ggplot2::scale_y_continuous(limits=c(0, NA), labels = scales::comma)
    else
        rv = rv + ggplot2::scale_y_continuous(labels = scales::comma)
    # browser()
    # how data points are plotted is conditional on 'split.by', but the facet_wrap is not
    if (!is.null(split.by)) {
        if (!is.null(df.sim)) {
            rv = rv + ggplot2::geom_line(data=df.sim.groupids.many.members, ggplot2::aes(x=year,y=value,group=groupid,
                                                                                         linetype = linetype.sim.by,
                                                                                         color = color.sim.by,
                                                                                         alpha = alpha,
                                                                                         linewidth = linewidth)) +
                ggplot2::geom_point(data=df.sim.groupids.one.member, size=2, ggplot2::aes(x=year, y=value,
                                                                                          color = color.sim.by,
                                                                                          shape = shape.sim.by))
            if (summary.type != 'individual.simulation')
                rv = rv + ggplot2::geom_ribbon(data=df.sim.groupids.many.members, ggplot2::aes(x=year, y=value,group=groupid,
                                                                                               fill = color.sim.by,
                                                                                               ymin = value.lower,
                                                                                               ymax = value.upper),
                                               alpha = style.manager$alpha.ribbon,
                                               outline.type = 'full')
        }
        if (!is.null(df.truth)) {
            rv = rv + ggnewscale::new_scale_fill() + ggplot2::scale_fill_manual(values = color.data.shaded.colors)
            rv = rv + ggplot2::guides(fill = ggplot2::guide_legend("data color", override.aes = list(shape = 21)))
            rv = rv + ggplot2::geom_point(data=df.truth, ggplot2::aes(x=year, y=value,
                                                                      fill=color.and.shade.data.by, # fill
                                                                      shape=shape.data.by))
        }
        
    } else {
        if (!is.null(df.sim)) {
            rv = rv + ggplot2::geom_line(data=df.sim.groupids.many.members, ggplot2::aes(x=year, y=value, group=groupid,
                                                                                         linetype = linetype.sim.by,
                                                                                         alpha = alpha,
                                                                                         linewidth = linewidth)) +
                ggplot2::geom_point(data=df.sim.groupids.one.member, size=2, ggplot2::aes(x=year, y=value,
                                                                                          color = color.sim.by,
                                                                                          shape=shape.sim.by))
            if (summary.type != 'individual.simulation') {
                rv = rv + ggplot2::geom_ribbon(data=df.sim.groupids.many.members, ggplot2::aes(x=year, y=value,group=groupid,
                                                                                               fill = color.sim.by,
                                                                                               ymin = value.lower,
                                                                                               ymax = value.upper),
                                               alpha = style.manager$alpha.ribbon,
                                               outline.type = 'full')
                # Remove the fill scale since we don't have more than one sim ribbon color
                if (style.manager$color.sim.by == "stratum")
                    rv = rv + ggplot2::guides(fill = "none")
            }
        }
        if (!is.null(df.truth)) {
            rv = rv + ggnewscale::new_scale_fill() + ggplot2::scale_fill_manual(values = color.data.shaded.colors)
            rv = rv + ggplot2::guides(fill = ggplot2::guide_legend("data color", override.aes = list(shape = 21)))
            rv = rv + ggplot2::geom_point(data=df.truth, size=2, ggplot2::aes(x=year, y=value, fill=color.and.shade.data.by, shape = shape.data.by))
        } 
    }
    # If don't have a split.by, and thus only 1 color for sim, probably, then remove legend for it.
    if (style.manager$color.sim.by == 'stratum' && is.null(split.by))
        rv = rv + ggplot2::guides(color = "none")
    # browser()
    if (is.null(facet.by))
        facet.formula = as.formula("~outcome")
    else
        facet.formula = as.formula("~outcome + facet.by")
    if (!is.null(n.facet.rows))
        rv = rv + ggplot2::facet_wrap(facet.formula, scales = 'free_y', nrow=n.facet.rows)
    else
        rv = rv + ggplot2::facet_wrap(facet.formula, scales = 'free_y')
    
    rv = rv +
        ggplot2::scale_alpha(guide='none') +
        ggplot2::labs(y=y.label)
    if (!is.null(df.sim))
        rv = rv + ggplot2::scale_linewidth(NULL, range=c(min(df.sim$linewidth), 1), guide = 'none')
    
    if (plot.year.lag.ratio) rv = rv + xlab("latter year")
    # browser()
    rv
    
    return(rv)
}