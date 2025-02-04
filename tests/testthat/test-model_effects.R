library(testthat)

# Load required packages
library(jheem2) # We'll need this for create.intervention.effect

# Source the file we're testing
source("../../src/adapters/interventions/model_effects.R")

test_that("PrEP effect configuration is valid", {
    # Get PrEP effect config
    prep_config <- get_effect_config("prep")

    # Test structure
    expect_type(prep_config, "list")
    expect_equal(prep_config$quantity_name, "oral.prep.uptake")
    expect_equal(prep_config$scale, "proportion")
    expect_type(prep_config$transform, "closure")
    expect_type(prep_config$create, "closure")

    # Test value transformation
    expect_equal(prep_config$transform(25), 0.25)
    expect_equal(prep_config$transform(100), 1.0)
})

test_that("Effect creation works with valid inputs", {
    # Create test settings
    start_time <- 2025
    end_time <- 2030
    coverage <- 25

    # Get config and create effect
    prep_config <- get_effect_config("prep")
    effect <- prep_config$create(start_time, end_time, coverage)

    # Test created effect
    expect_equal(class(effect)[1], "jheem.intervention.effect")
    expect_equal(effect$quantity.name, "oral.prep.uptake")
    expect_equal(effect$effect.values, 0.25)
})

test_that("Invalid intervention type throws error", {
    expect_error(
        get_effect_config("invalid_type"),
        "Unknown intervention type: invalid_type"
    )
})

test_that("Testing effect configuration is valid", {
    testing_config <- get_effect_config("testing")

    expect_type(testing_config, "list")
    expect_equal(testing_config$quantity_name, "general.population.testing")
    expect_equal(testing_config$scale, "rate")
    expect_type(testing_config$transform, "closure")
    expect_type(testing_config$create, "closure")
})

test_that("Testing effect creation works with valid inputs", {
    start_time <- 2025
    end_time <- 2030
    frequency <- 2 # twice per year

    testing_config <- get_effect_config("testing")
    effect <- testing_config$create(start_time, end_time, frequency)

    expect_equal(class(effect)[1], "jheem.intervention.effect")
    expect_equal(effect$quantity.name, "general.population.testing")
    expect_equal(effect$effect.values, 2) # No transformation needed for rate
})

test_that("Suppression effect configuration is valid", {
    suppression_config <- get_effect_config("suppression")

    expect_type(suppression_config, "list")
    expect_equal(suppression_config$quantity_name, "suppression.of.diagnosed")
    expect_equal(suppression_config$scale, "proportion")
    expect_type(suppression_config$transform, "closure")
    expect_type(suppression_config$create, "closure")

    expect_equal(suppression_config$transform(80), 0.8)
    expect_equal(suppression_config$transform(90), 0.9)
})

test_that("Effect creation works with valid inputs", {
    start_time <- 2025
    end_time <- 2030

    # Test PrEP
    prep_config <- get_effect_config("prep")
    prep_effect <- prep_config$create(start_time, end_time, 25)
    expect_equal(class(prep_effect)[1], "jheem.intervention.effect")
    expect_equal(prep_effect$quantity.name, "oral.prep.uptake")
    expect_equal(prep_effect$effect.values, 0.25)

    # Test Testing
    testing_config <- get_effect_config("testing")
    testing_effect <- testing_config$create(start_time, end_time, 2)
    expect_equal(class(testing_effect)[1], "jheem.intervention.effect")
    expect_equal(testing_effect$quantity.name, "general.population.testing")
    expect_equal(testing_effect$effect.values, 2)

    # Test Suppression
    suppression_config <- get_effect_config("suppression")
    suppression_effect <- suppression_config$create(start_time, end_time, 80)
    expect_equal(class(suppression_effect)[1], "jheem.intervention.effect")
    expect_equal(suppression_effect$quantity.name, "suppression.of.diagnosed")
    expect_equal(suppression_effect$effect.values, 0.8)
})
