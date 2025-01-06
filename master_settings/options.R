# in the future, make this from the specification

OUTCOME.OPTIONS <- list(
    values = c('incidence','new','prevalence','mortality','testing.rate','prep','suppression','diagnosed'),
    names = c("Incidence", "Reported Diagnoses", "Prevalence (Diagnosed)", "HIV Mortality","HIV Testing Rates","PrEP Coverage","Viral Suppression","Knowledge of Status"),
    code = 'outcome',
    label = "Outcome"
)

FACET.BY.OPTIONS <- list(
    values = c('none', 'age', 'race', 'sex', 'risk'),
    names = c("None", "Age", "Race/Ethnicity", "Sex", "Risk"),
    code = 'facet_by',
    label = "Facet By"
)

SUMMARY.TYPE.OPTIONS <- list(
    values = c('mean.and.interval', 'median.and.interval', 'individual.simulation'),
    names = c("Mean and Interval", "Median and Interval", "Individual Simulations"),
    code = 'summary_type',
    label = "Summary Type"
)


AGE.OPTIONS <- list(
    values = c("13-24 years", "25-34 years", "35-44 years", "45-54 years", "55+ years"),
    names = c("13-24 years", "25-34 years", "35-44 years", "45-54 years", "55+ years"),
    code = 'age',
    label = "Age Group",
    label.plural = 'Age Groups'
)

RACE.OPTIONS <- list(
    values = c("black", "hispanic","other"),
    names = c("Black", "Hispanic", "Other"),
    code = 'race',
    label = "Race/Ethnicity",
    label.plural = 'Races'
)

SEX.OPTIONS <- list(
    values = c("male","female"),
    names = c("Male", "Female"),
    code = 'sex',
    label = "Biological Sex",
    label.plural = 'Sexes'
)

RISK.OPTIONS.1 <- list(
    values = c("msm", "idu", "msm_idu", "heterosexual"),
    names = c("MSM", "IDU", "MSM+IDU", "Heterosexual"),
    code = 'risk',
    label = "Risk Factor",
    label.plural = 'Risk Factors'
)

RISK.OPTIONS.2 <- list(
    values = c("msm", "active_idu", "prior_idu", "msm_active_idu", "msm_prior_idu", "heterosexual"),
    names = c("MSM", "Active IDU", "Prior IDU", "MSM + Active IDU", "MSM + Prior IDU", "Heterosexual"),
    code = 'risk',
    label = "Risk Factor",
    label.plural = 'Risk Factors'
)

DIMENSION.VALUES.2 = list(
    age=AGE.OPTIONS,
    race=RACE.OPTIONS,
    sex=SEX.OPTIONS,
    risk=RISK.OPTIONS.2)