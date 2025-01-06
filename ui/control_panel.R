create.plot.control.panel <- function(suffix)
{
    tags$div(
        class='controls controls_narrow',
        
        checkboxGroupInput(inputId = paste0('outcomes_', suffix),
                           label = "Outcomes",
                           choiceValues = OUTCOME.OPTIONS$values,
                           choiceNames = OUTCOME.OPTIONS$names,
                           selected = OUTCOME.OPTIONS$values[1:2]),
        
        radioButtons(inputId = paste0('facet_by_', suffix),
                     label = "What to Facet By",
                     choiceValues = FACET.BY.OPTIONS$values,
                     choiceNames = FACET.BY.OPTIONS$names,
                     selected = FACET.BY.OPTIONS$values[1]),
        
        radioButtons(inputId = paste0('summary_type_', suffix),
                     label = "Summary Type",
                     choiceValues = SUMMARY.TYPE.OPTIONS$values,
                     choiceNames = SUMMARY.TYPE.OPTIONS$names,
                     selected = SUMMARY.TYPE.OPTIONS$values[1])
        
    ) #</div>
    
}

get.control.settings <- function(input, suffix)
{
    list(
        outcomes=get.selected.outcomes(input, suffix),
        facet.by=get.selected.facet.by(input, suffix),
        summary.type=get.selected.summary.type(input, suffix)
    )
}

get.main.settings <- function(input, suffix)
{
    list()
}

get.selected.outcomes <- function(input, suffix)
{
    input[[paste0('outcomes_', suffix)]]
}

get.selected.facet.by <- function(input, suffix)
{
    x=input[[paste0('facet_by_', suffix)]]
    if (x == 'none') return (NULL)
    else return(x)
}

get.selected.summary.type <- function(input, suffix)
{
    input[[paste0('summary_type_', suffix)]]
}