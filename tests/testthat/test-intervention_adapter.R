library(testthat)
library(jheem2)

# Source dependencies first
source("../../src/adapters/interventions/model_effects.R")
source("../../src/adapters/intervention_adapter.R")

test_that("create_custom_intervention handles valid settings", {
    # Mock settings as they would come from collect_custom_settings
    settings <- list(
        location = "baltimore",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c("13-24", "25-34"),
                    race_ethnicity = c("black", "hispanic"),
                    biological_sex = c("male"),
                    risk_factor = c("msm", "pwid")
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
                    risk_factor = c("msm", "pwid")
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
                    race_ethnicity = c("white"),
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
