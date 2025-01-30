# src/ui/components/common/plot_controls/control_section.R

#' Helper to create a control section
#' @param type Type of control section
#' @param config Section configuration
#' @param suffix Page suffix ('prerun' or 'custom')
#' @param ns Optional namespace function
create_control_section <- function(type, config, suffix, ns = NULL) {
    print("Creating control section:")
    print(paste("Type:", type))
    print(paste("Suffix:", suffix))
    print("Config:")
    print(str(config))

    # Map UI type to input ID prefix
    input_prefix <- switch(type,
        "stratification" = "facet_by", # Map UI "stratification" to technical "facet_by"
        "display" = "summary_type", # Map "display" to "summary_type"
        type # Default to using type as-is (e.g., "outcomes")
    )

    # Generate base input ID
    base_id <- paste0(input_prefix, "_", suffix)

    # Apply namespace if provided
    input_id <- if (!is.null(ns)) ns(base_id) else base_id
    print(paste("Generated input ID:", input_id))

    tags$div(
        class = paste("plot-control-section", type),

        # Section label
        tags$label(config$label),

        # Create appropriate input based on type
        switch(as.character(config$type),
            "checkbox" = checkboxGroupInput(
                inputId = input_id,
                label = NULL,
                choices = setNames(
                    sapply(config$options, `[[`, "id"),
                    sapply(config$options, `[[`, "label")
                )
            ),
            "radio" = radioButtons(
                inputId = input_id,
                label = NULL,
                choices = setNames(
                    sapply(config$options, `[[`, "id"),
                    sapply(config$options, `[[`, "label")
                )
            ),
            stop(sprintf("Unknown control type: %s", config$type))
        )
    )
}
