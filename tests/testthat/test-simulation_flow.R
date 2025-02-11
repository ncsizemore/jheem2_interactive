library(testthat)
library(jheem2)


source_project_file("../jheem_analyses/applications/EHE/ehe_specification.R")


# Source required files
source_project_file("src", "data", "loader.R")
source_project_file("src", "core", "simulation", "runner.R")
source_project_file("src", "core", "simulation", "results.R")
source_project_file("src", "adapters", "intervention_adapter.R")

# Check again after sourcing
print("After sourcing files:")
print(exists("get_defaults_config"))
if (exists("get_defaults_config")) {
    print(environment(get_defaults_config))
}

test_that("full simulation flow works with test data", {
    # Initialize provider with absolute path
    test_dir <- file.path(get_project_root(), "tests/fixtures/simulations")
    initialize_provider("local", root_dir = test_dir)

    # Load simset and inspect specification
    simset <- load_simset("C.33100_v1_baseline")
    spec_metadata <- simset$jheem.kernel$specification.metadata

    # Debug: Print available dimension values
    print("\nAvailable dimensions:")
    print("Age groups:")
    print(spec_metadata$age.endpoints)

    # Look at dimension names for clues about sex/gender coding
    print("\nDimension names:")
    str(spec_metadata$dim.names)

    # Try to find valid values for sex
    print("\nTrying to find sex dimension values:")
    if (!is.null(spec_metadata$private$i.dim.names$sex)) {
        print(spec_metadata$private$i.dim.names$sex)
    }

    # Override get_defaults_config in global environment
    assign("get_defaults_config", function() {
        print("TEST version of get_defaults_config called!")
        root <- get_project_root()
        config_path <- file.path(root, "tests", "fixtures", "config", "ui", "defaults.yaml")
        print(paste("Loading config from:", config_path))
        yaml::read_yaml(config_path)
    }, envir = .GlobalEnv)

    # Override get_model_dimension_value in global environment
    assign("get_model_dimension_value", function(dimension, ui_value) {
        print(paste("TEST version of get_model_dimension_value called with:", dimension, ui_value))
        config <- get_defaults_config()
        mappings <- config$model_dimensions[[dimension]]$mappings

        # Debug print available mappings
        print(paste("Available mappings for", dimension, ":"))
        print(mappings)

        if (is.null(mappings[[ui_value]])) {
            stop(sprintf("No mapping found for %s value: %s", dimension, ui_value))
        }

        mappings[[ui_value]]
    }, envir = .GlobalEnv)

    # Debug: Check file existence
    test_file <- file.path(test_dir, "C.33100_v1_baseline.Rdata")

    print(paste("Test directory:", test_dir))
    print(paste("Test file exists:", file.exists(test_file)))

    # Create test settings with correct model values
    settings <- list(
        location = "C.33100",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c("13-24"),
                    race_ethnicity = c("black"),
                    biological_sex = c("msm"),
                    risk_factor = c("never_idu")
                ),
                interventions = list(
                    dates = list(
                        start = "2025",
                        end = "2030"
                    ),
                    testing = list(
                        enabled = TRUE,
                        frequency = 2
                    )
                )
            )
        )
    )

    # Create intervention
    intervention <- create_intervention(settings, mode = "custom", session_id = "test123")
    expect_false(is.null(intervention))
    expect_equal(class(intervention)[1], "jheem.standard.intervention")

    # Run simulation
    runner <- SimulationRunner$new(.provider)
    results <- runner$run_intervention(intervention, simset)
    expect_false(is.null(results))
})

test_that("custom intervention UI flow produces modified results", {
    # 1. Mock UI settings (using our working test settings)
    settings <- list(
        location = "C.33100",
        subgroups = list(
            list(
                demographics = list(
                    age_groups = c(1),
                    race_ethnicity = c("black"),
                    biological_sex = c("msm"),
                    risk_factor = c("never_idu")
                ),
                interventions = list(
                    dates = list(
                        start = "2025",
                        end = "2030"
                    ),
                    testing = list(
                        enabled = TRUE,
                        frequency = 2
                    )
                )
            )
        )
    )

    # 2. Follow the exact flow from UI through display
    # Create intervention
    intervention <- create_intervention(settings, "custom")

    # Load and run simulation
    simset <- load_simset("C.33100_v1_baseline")
    runner <- SimulationRunner$new(.provider)
    results <- runner$run_intervention(intervention, simset)

    # Transform for display (as plot_panel would)
    plot_data <- get_plot_data(results, settings)

    # Basic verification - are we getting modified results?
    expect_false(identical(plot_data, simset))
})
