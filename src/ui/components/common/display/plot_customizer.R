# src/ui/components/common/display/plot_customizer.R

#' Customize a ggplot object from configuration
#' @param plot The ggplot object to customize
#' @param config The visualization configuration containing customization settings
#' @return The modified ggplot object
customize_plot_from_config <- function(plot, config) {
  # Debug print to see if function is being called
  print("[PLOT_CUSTOMIZER] customize_plot_from_config() called")
  
  # If no config provided or no customizations defined, return original plot
  if (is.null(config)) {
    print("[PLOT_CUSTOMIZER] config is NULL, returning original plot")
    return(plot)
  }
  
  # Debug print for config structure
  print("[PLOT_CUSTOMIZER] config structure:")
  print(str(config))
  
  if (is.null(config$plot_customizations)) {
    print("[PLOT_CUSTOMIZER] plot_customizations section is NULL, returning original plot")
    return(plot)
  }
  
  customizations <- config$plot_customizations
  
  # Debug print for customizations
  print("[PLOT_CUSTOMIZER] Customizations to apply:")
  print(str(customizations))
  
  # Apply a complete theme if specified
  if (!is.null(customizations$theme_name)) {
    theme_name <- customizations$theme_name
    print(paste("[PLOT_CUSTOMIZER] Applying theme:", theme_name))
    
    # Apply the specified theme
    if (theme_name == "minimal") {
      plot <- plot + ggplot2::theme_minimal()
    } else if (theme_name == "light") {
      plot <- plot + ggplot2::theme_light()
    } else if (theme_name == "classic") {
      plot <- plot + ggplot2::theme_classic()
    } else if (theme_name == "bw") {
      plot <- plot + ggplot2::theme_bw()
    }
  }
  
  # Apply individual theme elements
  if (!is.null(customizations$theme)) {
    theme_args <- list()
    
    # Process simple theme elements
    if (!is.null(customizations$theme$background_color)) {
      print(paste("[PLOT_CUSTOMIZER] Setting background color:", customizations$theme$background_color))
      theme_args$panel.background <- ggplot2::element_rect(fill = customizations$theme$background_color)
    }
    
    if (!is.null(customizations$theme$grid_color)) {
      print(paste("[PLOT_CUSTOMIZER] Setting grid color:", customizations$theme$grid_color))
      theme_args$panel.grid.major <- ggplot2::element_line(color = customizations$theme$grid_color)
      theme_args$panel.grid.minor <- ggplot2::element_line(color = customizations$theme$grid_color, linetype = "dashed")
    }
    
    if (!is.null(customizations$theme$axis_color)) {
      theme_args$axis.line <- ggplot2::element_line(color = customizations$theme$axis_color)
    }
    
    if (!is.null(customizations$theme$text_family)) {
      theme_args$text <- ggplot2::element_text(family = customizations$theme$text_family)
    }
    
    if (!is.null(customizations$theme$text_size)) {
      print(paste("[PLOT_CUSTOMIZER] Setting text size:", customizations$theme$text_size))
      theme_args$text <- ggplot2::element_text(size = customizations$theme$text_size)
    }
    
    if (!is.null(customizations$theme$legend_position)) {
      print(paste("[PLOT_CUSTOMIZER] Setting legend position:", customizations$theme$legend_position))
      theme_args$legend.position <- customizations$theme$legend_position
    }
    
    if (!is.null(customizations$theme$legend_direction)) {
      theme_args$legend.direction <- customizations$theme$legend_direction
    }
    
    if (!is.null(customizations$theme$legend_box)) {
      theme_args$legend.box <- customizations$theme$legend_box
    }
    
    # Apply theme modifications
    if (length(theme_args) > 0) {
      print("[PLOT_CUSTOMIZER] Applying theme modifications")
      plot <- plot + do.call(ggplot2::theme, theme_args)
    }
  }
  
  # Apply axis formatting
  if (!is.null(customizations$axes)) {
    if (!is.null(customizations$axes$x_title)) {
      print(paste("[PLOT_CUSTOMIZER] Setting x-axis title:", customizations$axes$x_title))
      plot <- plot + ggplot2::xlab(customizations$axes$x_title)
    }
    
    if (!is.null(customizations$axes$y_title)) {
      print(paste("[PLOT_CUSTOMIZER] Setting y-axis title:", customizations$axes$y_title))
      plot <- plot + ggplot2::ylab(customizations$axes$y_title)
    }
    
    if (!is.null(customizations$axes$x_breaks)) {
      print("[PLOT_CUSTOMIZER] Setting x-axis breaks")
      plot <- plot + ggplot2::scale_x_continuous(breaks = customizations$axes$x_breaks)
    }
    
    # Apply custom formatting if specified
    if (!is.null(customizations$axes$x_format)) {
      print(paste("[PLOT_CUSTOMIZER] Setting x-axis format:", customizations$axes$x_format))
      if (customizations$axes$x_format == "comma") {
        plot <- plot + ggplot2::scale_x_continuous(labels = scales::comma)
      } else if (customizations$axes$x_format == "percent") {
        plot <- plot + ggplot2::scale_x_continuous(labels = scales::percent)
      }
    }
    
    if (!is.null(customizations$axes$y_format)) {
      print(paste("[PLOT_CUSTOMIZER] Setting y-axis format:", customizations$axes$y_format))
      if (customizations$axes$y_format == "comma") {
        plot <- plot + ggplot2::scale_y_continuous(labels = scales::comma)
      } else if (customizations$axes$y_format == "percent") {
        plot <- plot + ggplot2::scale_y_continuous(labels = scales::percent)
      }
    }
  }
  
  # Apply facet customizations
  if (!is.null(customizations$facets)) {
    theme_args <- list()
    
    if (!is.null(customizations$facets$strip_background)) {
      print(paste("[PLOT_CUSTOMIZER] Setting facet strip background:", customizations$facets$strip_background))
      theme_args$strip.background <- ggplot2::element_rect(fill = customizations$facets$strip_background)
    }
    
    if (!is.null(customizations$facets$strip_text_size)) {
      print(paste("[PLOT_CUSTOMIZER] Setting facet strip text size:", customizations$facets$strip_text_size))
      theme_args$strip.text <- ggplot2::element_text(size = customizations$facets$strip_text_size)
    }
    
    # Apply facet theme modifications
    if (length(theme_args) > 0) {
      print("[PLOT_CUSTOMIZER] Applying facet theme modifications")
      plot <- plot + do.call(ggplot2::theme, theme_args)
    }
  }
  
  # Debug print to confirm we're returning a valid plot
  print("[PLOT_CUSTOMIZER] Returning customized plot")
  print(class(plot))
  
  return(plot)
}
