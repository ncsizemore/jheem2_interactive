#' Creates the FAQ page content
create_faq_content <- function() {
    tagList(
        tags$div(
            class = "page-container",
            # Header
            tags$header(
                class = "page-header",
                tags$h1("Frequently Asked Questions"),
                tags$h2("About the Johns Hopkins Epidemiologic and Economic Model (JHEEM)")
            ),

            # Q&A Content
            tags$div(
                class = "page-content",

                # City Question
                tags$details(
                    class = "faq-item",
                    tags$summary(
                        class = "faq-question",
                        "Why is my city not an option?"
                    ),
                    tags$div(
                        class = "faq-answer",
                        tags$p(
                            "To begin, we have calibrated our model to the 32 metropolitan statistical areas (MSAs) ",
                            "that encompass the 48 high-burden counties plus Washington DC identified in the Ending ",
                            "the HIV Epidemic Initiative."
                        ),
                        tags$p(
                            "However, the calibration process is semi-automated, meaning that new locations can be ",
                            "fitted if we have the epidemiologic data to fit to (data like reported diagnoses, ",
                            "estimated prevalence, proportion of PWH who are suppressed). Please ",
                            tags$a(
                                onclick = 'Shiny.setInputValue("link_from_overview", "contact_us", {priority: "event"})',
                                "contact us"
                            ),
                            " if you are interested in having the JHEEM calibrated to a new location."
                        )
                    )
                ),

                # Baseline Values Question
                tags$details(
                    class = "faq-item",
                    tags$summary(
                        class = "faq-question",
                        "What are the baseline values for HIV testing rates, PrEP uptake, and viral suppression?"
                    ),
                    tags$div(
                        class = "faq-answer",
                        tags$p(
                            "The baseline values for HIV testing, PrEP uptake, and viral suppression are different ",
                            "for each subgroup (each combination of age, race, sex, and risk factor). They also ",
                            "change over time (generally speaking, they increase). You can look at what we use by ",
                            "selecting \"HIV Testing\", \"PrEP Uptake\", or \"Viral Suppression\" as Outcomes in ",
                            "the Figure Settings. (Note that these values are weighted averages of all the subgroup values)."
                        ),
                        tags$p(
                            "We treat these as uncertain quantities in our calibration process. In other words, ",
                            "because we don't know exactly what, say, PrEP uptake is among 13-24 year-old Black MSM ",
                            "in Atlanta, we allow it vary from simulation to simulation. The calibration process ",
                            "selects values that are consistent with local data on each type of parameter:"
                        ),
                        tags$ul(
                            tags$li(
                                "For ", tags$b("HIV Testing"), ", we calibrate to (a) the proportion of PWH aware of ",
                                "their diagnosis (estimated at the state level by the CDC) and (b) the proportion of ",
                                "individuals who report ever having an HIV test, as gathered by the Behavioral Risk ",
                                "Factor Surveillance System (BRFSS). Proportions tested for the total population are ",
                                "available at the MSA-level, and proportions by age, sex, and race are available at ",
                                "the state level."
                            ),
                            tags$li(
                                "For ", tags$b("PrEP Uptake"), ", we calibrate to the number of prescriptions for ",
                                "emtricitabine-tenofovir as collated by ",
                                tags$a(
                                    href = "https://aidsvu.org/prep/",
                                    target = "_blank",
                                    "AidsVu"
                                ),
                                " (total and stratified by age and sex)."
                            ),
                            tags$li(
                                "For ", tags$b("Viral Suppression"), ", we calibrate to the proportion of PWH who ",
                                "are virally suppressed as reported by local health departments. When available, ",
                                "we use data stratified by age, race, sex, and risk factor in addition to total proportions."
                            )
                        ),
                        tags$p(
                            "This process lets us explore a range of possible values for baseline testing rates, ",
                            "PrEP uptake, and suppression that are consistent with the data we observe in each city."
                        )
                    )
                )
            )
        )
    )
}
