# components/display/plot.R
# Import required libraries
library(ggplot2)
library(ggnewscale)
library(scales)

source('plotting/simplot/prepare_plot.R')  # We'll create this
source('plotting/simplot/execute_plot.R')  # And this

#' Create simulation plot
#' @export
simplot <- function(...,
                    outcomes = NULL,
                    corresponding.data.outcomes = NULL,
                    split.by = NULL,
                    facet.by = NULL,
                    dimension.values = list(),
                    plot.which = c('both', 'sim.only', 'data.only')[1],
                    summary.type = c('individual.simulation', 'mean.and.interval', 'median.and.interval')[1],
                    plot.year.lag.ratio = F,
                    n.facet.rows = NULL,
                    data.manager = get.default.data.manager(),
                    style.manager = get.default.style.manager(),
                    debug = F) {
    
    prepared.plot.data = prepare_plot(...,
                                      outcomes = outcomes,
                                      corresponding.data.outcomes = corresponding.data.outcomes,
                                      split.by = split.by,
                                      facet.by = facet.by,
                                      dimension.values = dimension.values,
                                      plot.which = plot.which,
                                      summary.type = summary.type,
                                      plot.year.lag.ratio = plot.year.lag.ratio,
                                      data.manager = data.manager,
                                      debug = debug
    )
    
    execute_plot(prepared.plot.data,
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