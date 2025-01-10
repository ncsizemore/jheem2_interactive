# config/interventions/options.R

#' Pre-defined options for intervention selectors
#' These configurations define the available choices for each intervention selector component

#' Available intervention aspects
INTERVENTION_ASPECTS <- list(
    none = list(
        id = "none",
        label = "None"
    ),
    testing = list(
        id = "hivtesting",
        label = "HIV Testing"
    ),
    prep = list(
        id = "prep", 
        label = "PrEP Coverage"
    ),
    viral = list(
        id = "viralsuppression",
        label = "Viral Suppression"
    ),
    exchange = list(
        id = "needleexchange",
        label = "Needle Exchange"
    ),
    moud = list(
        id = "moud",
        label = "MOUDs"
    )
)

#' Available target populations
POPULATION_GROUPS <- list(
    all = list(
        id = "all",
        label = "All populations"
    ),
    age = list(
        id = "age_groups",
        label = HTML("By age groups:<br/>13-24, 25-34, 35-44, 45-54, 55+")
    ),
    risk = list(
        id = "risk_groups",
        label = HTML("By risk groups:<br/>MSM, IDU, heterosexual contact")
    )
)

#' Available time frames
TIMEFRAMES <- list(
    immediate = list(
        id = "2024_2025",
        label = "2024-2025 (Immediate)"
    ),
    short = list(
        id = "2024_2026",
        label = "2024-2026 (Short-term)"
    ),
    medium = list(
        id = "2024_2028",
        label = "2024-2028 (Medium-term)"
    ),
    long = list(
        id = "2024_2030",
        label = "2024-2030 (Long-term)"
    )
)

#' Available intensity levels
INTENSITIES <- list(
    moderate = list(
        id = "moderate",
        label = "Moderate increase in coverage"
    ),
    substantial = list(
        id = "substantial",
        label = "Substantial increase in coverage"
    ),
    aggressive = list(
        id = "aggressive",
        label = "Aggressive increase in coverage"
    ),
    maximum = list(
        id = "maximum",
        label = "Maximum feasible coverage"
    )
)