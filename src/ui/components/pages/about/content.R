#' Creates the about page content sections
create_about_content <- function() {
    tagList(
        # Navigation
        tags$nav(
            class = "page-nav",
            tags$a(href = "#overview", "Overview"),
            tags$a(href = "#model-structure", "Model Structure"),
            tags$a(href = "#calibration", "Calibration"),
            tags$a(href = "#interventions", "Interventions"),
            tags$a(href = "#publications", "Publications"),
            tags$a(href = "#funding", "Funding Sources")
        ),
        tags$div(
            class = "page-container",
            # Header
            tags$header(
                class = "page-header",
                tags$h1("The Johns Hopkins Epidemiologic and Economic Model (JHEEM)"),
                tags$h2("A Mathematical Model in Service of Ending the HIV Epidemic in the US")
            ),

            # Content sections
            tags$div(
                class = "page-content",
                # Overview
                tags$section(
                    id = "overview",
                    class = "page-section",
                    tags$h3("Overview"),
                    tags$p(
                        "The JHEEM is a dynamic, compartmental model of HIV. We have calibrated the model to recapitulate the HIV ",
                        "Epidemic in 32 cities identified by the Ending the HIV Epidemic Initiative (EtE). In each of these cities, we can ",
                        "experiment with different levels of the EtE pillars - HIV testing, viral suppression among people with HIV (PWH), and ",
                        "pre-exposure prophylaxis (PrEP) among individuals at risk for HIV - to project their effect on future transmission."
                    )
                ),

                # Model Structure
                tags$section(
                    id = "model-structure",
                    class = "page-section",
                    tags$h3("Model Structure"),
                    tags$figure(
                        class = "page-figure",
                        tags$img(
                            src = "images/model_unit.png",
                            alt = "Schematic of Model Structure"
                        ),
                        tags$figcaption(
                            "The JHEEM represents the adult population (13 years old and older) as stratified into seven compartments with respect to HIV.",
                            tags$br(), tags$br(),
                            "The population is further stratified by age (13-24, 25-34, 35-44, 45-54, and ≥55 years old), ",
                            "race/ethnicity (Black, Hispanic, and other), sex/sexual behavior (female, heterosexual male, and MSM), ",
                            "and IV drug use (never use, active use, and prior use), for a total of 945 compartments across ",
                            "135 strata of age, race, sex, and IV drug use."
                        )
                    )
                ),

                # Calibration
                tags$section(
                    id = "calibration",
                    class = "page-section",
                    tags$h3("Calibration"),
                    tags$p(
                        "The JHEEM includes 131 variable parameters. Running the model with one set of parameter values yields a ",
                        "simulation, which comprises simulated numbers of infections past and future."
                    ),
                    tags$p(
                        "We calibrated the model separately for 32 cities to 10 calibration targets:"
                    ),
                    tags$ol(
                        tags$li(tags$b("Reported Diagnoses"), " from 2009 to 2017 from the CDC."),
                        tags$li(tags$b("Prevalence"), " from 2008 to 2016 from the CDC."),
                        tags$li(tags$b("Mortality"), " in PWH from 2009 to 2016."),
                        tags$li(
                            "The proportion of ", tags$b("PWH aware of their diagnosis"),
                            " from 2010 to 2018, from state-level estimates provided by the CDC ",
                            "(except where local health departments provided publicly available estimates)."
                        ),
                        tags$li(
                            "The number of PWH who were ", tags$b("virally suppressed"),
                            " as reported by local health departments. We included all values from 2010 to 2018 which were publicly available."
                        ),
                        tags$li(
                            "The number of individuals receiving a ",
                            tags$b("prescription for emtricitabine/tenofovir"), ", as reported by AIDSVu."
                        ),
                        tags$li("The probability of receiving ", tags$b("HIV testing")),
                        tags$li("The prevalence of ", tags$b("injection drug use"), ", estimated from NSDUH"),
                        tags$li("The ", tags$b("cumulative mortality"), " of HIV up to 2002, obtained from CDC Wonder."),
                        tags$li("Reported ", tags$b("AIDS diagnoses"), " from 1998-2002, obtained from CDC Wonder.")
                    ),
                    tags$p(
                        "The statistical procedure that implements the calibration is Adaptive Metropolis Sampling, a Bayesian method ",
                        "that simulates the model parameters tens of thousands of times to approximate their probability distributions. ",
                        "This web tool generates projections using a random subsample of 80 simulations."
                    )
                ),

                # Interventions
                tags$section(
                    id = "interventions",
                    class = "page-section",
                    tags$h3("Interventions"),
                    tags$p(
                        "Interventions may be targeted to any of the 135 combinations of age, race, sex/sexual behavior, and IDU status. ",
                        "We allow interventions to affect three aspects of HIV management:"
                    ),
                    tags$ol(
                        tags$li(
                            tags$b("HIV Testing"), " – The rate at which undiagnosed PWH are diagnosed"
                        ),
                        tags$li(
                            tags$b("Viral Suppression"), " among PWH with diagnosed HIV – The proportion of PWH (aware of their diagnoses) ",
                            "who are virally suppressed. We assume that suppressed PWH do not transmit HIV, so the transmission of HIV from ",
                            "a demographic stratum decreases with increasing proportion suppressed in the stratum."
                        ),
                        tags$li(
                            tags$b("Pre-Exposure Prophylaxis (PrEP)"), " – For each demographic stratum of the uninfected population we set ",
                            "a proportion of individuals ", tags$i("who are at risk for acquiring HIV"), " who are enrolled in a PrEP program, ",
                            "which we conceive of as both a prescription for emtricitabine/tenofovir and laboratory monitoring every three months. ",
                            "This parameter has two effects: (a) for those on PrEP, the rate of acquisition of HIV is reduced by 86% for male-to-male ",
                            "sexual transmission, 75% for heterosexual transmission, and 49% for IV transmission, and (b) those who were infected ",
                            "while on PrEP move from undiagnosed to diagnosed HIV at an average rate of every three months."
                        )
                    )
                ),

                # Publications
                tags$section(
                    id = "publications",
                    class = "page-section",
                    tags$h3("Publications on the JHEEM"),
                    tags$ul(
                        tags$li(
                            "Perry A, Kasaie P, Dowdy DW, Shah M. What Will It Take to Reduce HIV Incidence in the United States: ",
                            "A Mathematical Modeling Analysis. Open Forum Infect Dis. 2018;5(2):ofy008."
                        ),
                        tags$li(
                            "Shah M, Perry A, Risher K, et al. Effect of the US National HIV/AIDS Strategy targets for improved HIV ",
                            "care engagement: a modelling study. Lancet HIV. 2016;3(3):e140-146."
                        ),
                        tags$li(
                            "Shah M, Risher K, Berry SA, Dowdy DW. The Epidemiologic and Economic Impact of Improving HIV Testing, ",
                            "Linkage, and Retention in Care in the United States. Clin Infect Dis. 2016;62(2):220-229."
                        )
                    )
                ),

                # Funding
                tags$section(
                    id = "funding",
                    class = "page-section",
                    tags$h3("Funding Sources"),
                    tags$p(
                        "This project is supported by grants from the National Institute of Mental Health (K08MH118094) and the ",
                        "National Institute of Allergy and Infectious Diseases (K01AI138853)."
                    )
                )
            )
        )
    )
}
