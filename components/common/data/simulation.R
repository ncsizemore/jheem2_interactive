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
    simset.list = list(simset=simset),
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

#' Format simulation data for table display
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
  
  # Format numbers
  format_number <- function(x) {
    ifelse(is.na(x), "NA",
           ifelse(x >= 100, as.character(round(x)), 
                  as.character(round(x, 1))))
  }
  
  # Create base data frame
  sim_data <- data.frame(
    Year = df.sim$year,
    Outcome = df.sim$outcome.display.name,
    Source = "Projected",
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
  
  # Get dimension columns from config
  dimension_ids <- sapply(config$plot_controls$stratification$options, function(x) x$id)
  
  # Find which dimensions are in the data
  direct_dims <- intersect(names(df.sim), dimension_ids)
  facet_cols <- grep("^facet\\.by\\d+$", names(df.sim), value = TRUE)
  
  # Add dimensions
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
  
  # Add truth data if available
  if (!is.null(df.truth) && nrow(df.truth) > 0) {
    truth_data <- data.frame(
      Year = df.truth$year,
      Outcome = df.truth$outcome.display.name,
      Value = format_number(df.truth$value),
      Source = "Historical",
      stringsAsFactors = FALSE
    )
    
    # Add Simulation column if needed
    if ("Simulation" %in% names(sim_data)) {
      truth_data$Simulation <- NA_real_
    }
    
    # Add dimension columns
    extra_cols <- setdiff(names(sim_data), 
                          c("Year", "Outcome", "Value", "Source", "Simulation"))
    
    for (col in extra_cols) {
      if (grepl("^Category", col)) {
        facet_num <- as.numeric(gsub("Category", "", col))
        truth_col <- paste0("facet.by", facet_num)
        truth_data[[col]] <- if(truth_col %in% names(df.truth)) {
          df.truth[[truth_col]]
        } else {
          NA
        }
      } else {
        truth_data[[col]] <- if(col %in% names(df.truth)) {
          df.truth[[col]]
        } else {
          NA
        }
      }
    }
    
    sim_data <- rbind(sim_data, truth_data)
  }
  
  # Sort rows
  sort_cols <- list(sim_data$Year)
  if ("Simulation" %in% names(sim_data)) {
    sort_cols <- c(sort_cols, list(sim_data$Simulation))
  }
  
  dimension_cols <- setdiff(names(sim_data), 
                            c("Year", "Simulation", "Outcome", "Value", "Source"))
  for (col in dimension_cols) {
    sort_cols <- c(sort_cols, list(sim_data[[col]]))
  }
  sort_cols <- c(sort_cols, list(sim_data$Source, sim_data$Outcome))
  
  sim_data <- sim_data[do.call(order, sort_cols), ]
  
  # Rename dimension columns
  if (!is.null(transformed_data$plot$details$facet.dims)) {
    old_names <- grep("^Category\\d+$", names(sim_data), value = TRUE)
    if (length(old_names) > 0) {
      new_names <- sapply(transformed_data$plot$details$facet.dims, function(dim_id) {
        config$plot_controls$stratification$options[[dim_id]]$label
      })
      if (length(old_names) == length(new_names)) {
        names(sim_data)[match(old_names, names(sim_data))] <- new_names
      }
    }
  }
  
  sim_data
}

#' Get data prepared for table display
#' @param simset jheem simulation set object
#' @param settings list of display settings
#' @return Data frame ready for table display
get_table_data <- function(simset, settings) {
  transform_simulation_data(simset, settings)
}