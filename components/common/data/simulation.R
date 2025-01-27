# components/common/data/simulation.R

#' Get simulation data based on settings and mode
#' @param settings List of settings that determine the simulation
#' @param mode Either "prerun" or "custom"
#' @return jheem simulation set
get_simulation_data <- function(settings, mode = c("prerun", "custom")) {
  mode <- match.arg(mode)
  print(paste("Getting simulation data for mode:", mode))
  print("Settings:")
  str(settings)

  # For now, load test data for both modes
  # Later this will:
  # - Load appropriate pre-run data for prerun mode
  # - Run model for custom mode
  simset <- get(load("simulations/init.pop.ehe_simset_2024-12-16_C.12580.Rdata"))

  print(paste("Loaded simulation data of class:", class(simset)[1]))
  return(simset)
}

#' Transform simulation data for visualization
#' @param simset jheem simulation set object
#' @param settings list with:
#'   outcomes - character vector of outcomes to include
#'   facet.by - character vector of dimensions to facet by (or NULL)
#'   summary.type - type of summary to calculate
#' @return Transformed data structure
transform_simulation_data <- function(simset, settings) {
  print("Starting data transformation")
  print("Settings:")
  str(settings)

  if (is.null(settings$outcomes)) {
    stop("outcomes must be specified in settings")
  }

  # Get raw plot data using prepare.plot
  plot_data <- prepare.plot(
    simset.list = list(simset = simset),
    outcomes = settings$outcomes,
    facet.by = settings$facet.by,
    summary.type = settings$summary.type
  )

  # Structure the result to match expected format
  result <- list(
    plot = plot_data
  )

  print("Transformed data structure:")
  str(result)

  return(result)
}

#' Get data prepared for plot display
#' @param simset jheem simulation set object
#' @param settings list of display settings
#' @return Raw simulation set for plot display
get_plot_data <- function(simset, settings) {
  simset
}


#' Format table data for display
#' @param transformed_data Output from transform_simulation_data
#' @param config Configuration list from get_defaults_config
#' @return Formatted data frame for table display
format_table_data <- function(transformed_data, config) {
  if (is.null(transformed_data) || is.null(transformed_data$plot)) {
    return(data.frame())
  }

  # Extract components
  df.sim <- transformed_data$plot$df.sim
  df.truth <- transformed_data$plot$df.truth
  is_summary <- "value.mean" %in% names(df.sim)

  # Helper for number formatting
  format_number <- function(x) {
    ifelse(is.na(x), "NA",
      ifelse(x >= 100, as.character(round(x)),
        as.character(round(x, 1))
      )
    )
  }

  # Save current options and ensure they're restored
  old_digits <- getOption("digits")
  on.exit(options(digits = old_digits))
  options(digits = 7)

  # Create base data frame
  sim_data <- data.frame(
    Year = df.sim$year,
    Outcome = df.sim$outcome.display.name,
    Source = rep("Projected", nrow(df.sim)),
    stringsAsFactors = FALSE
  )

  # Add values based on mode
  if (is_summary) {
    sim_data$Value <- paste0(
      format_number(df.sim$value.mean), " (",
      format_number(df.sim$value.lower), "-",
      format_number(df.sim$value.upper), ")"
    )
  } else {
    sim_data$Value <- format_number(df.sim$value)
    if ("sim" %in% names(df.sim)) {
      sim_data$Simulation <- as.numeric(as.character(df.sim$sim))
    }
  }

  # Add dimension columns
  dimension_ids <- sapply(config$plot_controls$stratification$options, function(x) x$id)
  direct_dims <- intersect(names(df.sim), dimension_ids)
  facet_cols <- grep("^facet\\.by\\d+$", names(df.sim), value = TRUE)

  if (length(direct_dims) > 0) {
    for (col in direct_dims) {
      sim_data[[col]] <- df.sim[[col]]
    }
  } else if (length(facet_cols) > 0) {
    for (i in seq_along(facet_cols)) {
      col_name <- paste0("Category", i)
      sim_data[[col_name]] <- df.sim[[facet_cols[i]]]
    }
  }

  # Get column order from config
  ordered_cols <- character(0)
  for (col in config$table_structure$display_order) {
    if (col == "dimensions") {
      dim_cols <- setdiff(
        names(sim_data),
        sapply(config$table_structure$base_columns, function(x) x$id)
      )
      ordered_cols <- c(ordered_cols, dim_cols)
    } else if (col %in% names(sim_data)) {
      ordered_cols <- c(ordered_cols, col)
    }
  }

  # Return data frame with columns in configured order
  sim_data[, ordered_cols]
}

#' Get data prepared for table display
#' @param simset jheem simulation set object
#' @param settings list of display settings
#' @return Data frame ready for table display
get_table_data <- function(simset, settings) {
  transform_simulation_data(simset, settings)
}
