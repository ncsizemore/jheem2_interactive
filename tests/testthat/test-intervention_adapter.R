library(testthat)
library(jheem2)

# Source dependencies first
source("../../src/adapters/interventions/model_effects.R")
source("../../src/adapters/intervention_adapter.R")

test_that("create_custom_intervention handles valid settings", {
    # Override just get_model_dimension_value
    assign("get_model_dimension_value", function(dimension, ui_value) {
        print(paste("TEST version of get_model_dimension_value called with:", dimension, ui_value))
        config <- get_defaults_config()
        mappings <- config$model_dimensions[[dimension]]$mappings

        if (is.null(mappings[[ui_value]])) {
            stop(sprintf("No mapping found for %s value: %s", dimension, ui_value))
        }

        mappings[[ui_value]]
    }, envir = .GlobalEnv)

    # Mock settings as they would come from collect_custom_settings
    settings <- list(
        location = "C.12580",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c("13-24", "25-34"),
                    race_ethnicity = c("black", "hispanic"),
                    biological_sex = c("male"),
                    risk_factor = c("msm", "active_idu")
                ),
                interventions = list(
                    dates = list(
                        start = "2025",
                        end = "2030"
                    ),
                    prep = list(
                        enabled = TRUE,
                        coverage = 25
                    ),
                    testing = list(
                        enabled = TRUE,
                        frequency = 2
                    )
                )
            )
        )
    )

    intervention <- create_custom_intervention(settings)
    expect_equal(class(intervention)[1], "jheem.standard.intervention")
})

test_that("create_custom_intervention returns null intervention when no effects", {
    # Mock settings with no enabled interventions
    settings <- list(
        location = "baltimore",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c("13-24"),
                    race_ethnicity = c("black"),
                    biological_sex = c("male"),
                    risk_factor = c("msm")
                ),
                interventions = list(
                    dates = list(
                        start = "2025",
                        end = "2030"
                    ),
                    prep = list(
                        enabled = FALSE
                    ),
                    testing = list(
                        enabled = FALSE
                    )
                )
            )
        )
    )

    intervention <- create_custom_intervention(settings)
    expect_equal(class(intervention)[1], "null.intervention") # Updated class name
})

test_that("create_intervention handles settings from UI collector", {
    # Mock the exact format from collect_custom_settings()
    settings <- list(
        # Plot settings (should be ignored by intervention creation)
        plot_type = "incidence",
        plot_metric = "count",

        # Intervention settings
        location = "baltimore",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c("13-24", "25-34"),
                    race_ethnicity = c("black", "hispanic"),
                    biological_sex = c("male"),
                    risk_factor = c("msm", "active_idu")
                ),
                interventions = list(
                    dates = list(
                        start = "2025",
                        end = "2030"
                    ),
                    testing = list(
                        enabled = TRUE,
                        frequency = 2
                    ),
                    prep = list(
                        enabled = TRUE,
                        coverage = 25
                    ),
                    suppression = list(
                        enabled = TRUE,
                        proportion = 90
                    )
                )
            ),
            # Second subgroup with different settings
            list(
                demographics = list(
                    age_groups = c("35-44"),
                    race_ethnicity = c("other"),
                    biological_sex = c("female"),
                    risk_factor = c("heterosexual")
                ),
                interventions = list(
                    dates = list(
                        start = "2025",
                        end = "2030"
                    ),
                    testing = list(
                        enabled = TRUE,
                        frequency = 1
                    ),
                    prep = list(
                        enabled = FALSE
                    ),
                    suppression = list(
                        enabled = TRUE,
                        proportion = 85
                    )
                )
            )
        )
    )

    intervention <- create_intervention(settings, mode = "custom")
    expect_equal(class(intervention)[1], "jheem.standard.intervention")

    # TODO: Add more specific assertions about the created intervention
    # - Should have effects from both subgroups
    # - Values should be correctly transformed
    # - Dates should be numeric
})

test_that("create_custom_intervention handles multiple subgroups", {
    # Mock settings with two subgroups
    settings <- list(
        location = "C.12580",
        subgroups = list(
            # First subgroup: Young MSM with PrEP
            list(
                demographics = list(
                    age_groups = c("13-24", "25-34"),
                    race_ethnicity = NULL,
                    biological_sex = "male",
                    risk_factor = "msm"
                ),
                interventions = list(
                    dates = list(
                        start = "2023",
                        end = "2025"
                    ),
                    prep = list(
                        enabled = TRUE,
                        coverage = 25
                    ),
                    testing = list(
                        enabled = FALSE
                    ),
                    suppression = list(
                        enabled = FALSE
                    )
                )
            ),
            # Second subgroup: All races with testing
            list(
                demographics = list(
                    age_groups = NULL,
                    race_ethnicity = c("black", "hispanic", "other"),
                    biological_sex = NULL,
                    risk_factor = NULL
                ),
                interventions = list(
                    dates = list(
                        start = "2023",
                        end = "2025"
                    ),
                    prep = list(
                        enabled = FALSE
                    ),
                    testing = list(
                        enabled = TRUE,
                        frequency = 2
                    ),
                    suppression = list(
                        enabled = FALSE
                    )
                )
            )
        )
    )

    # Create intervention
    intervention <- create_custom_intervention(settings)

    # Verify intervention was created
    expect_false(is.null(intervention))

    # Verify it's not a null intervention
    expect_false(identical(intervention, jheem2:::get.null.intervention()))

    # TODO: Add more specific checks about the combined intervention
    # These would depend on the exact behavior of union.interventions
})

test_that("create_intervention handles session IDs", {
    settings <- list(
        location = "baltimore",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c("13-24"),
                    race_ethnicity = c("black")
                ),
                interventions = list(
                    dates = list(start = "2025", end = "2030"),
                    testing = list(enabled = TRUE, frequency = 2)
                )
            )
        )
    )

    # Test with session ID
    intervention <- create_intervention(settings, mode = "custom", session_id = "test123")
    expect_match(intervention$code, "^c\\.test123\\.")

    # Test without session ID
    intervention <- create_intervention(settings, mode = "custom")
    expect_match(intervention$code, "^c\\.[0-9]")
})
