#' Pre-run intervention interface components
#' 
#' This module provides the UI components for selecting pre-run intervention 
#' parameters through a multi-step selection process.
#' 
#' Selection flow:
#' 1. Intervention aspect (e.g., HIV Testing, PrEP)
#' 2. Target population
#' 3. Time frame
#' 4. Intervention intensity

source('config/interventions/config.R')

CONFIG <- get_intervention_config()

#' Create the main pre-run interventions panel
#' @return A shiny UI element containing the complete pre-run interface
make.prerun.content <- function() {
    # Intervention aspect options
    intervention_aspects <- list(
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
    
    PRERUN.CONTENT = tags$table(id='prerun_table',
                                class='display_table fill_page1', 
                                tags$tbody(class='display_tbody',
                                           
                                           ##-- HEADERS AND DISPLAY --##  
                                           tags$tr(
                                               #-- Left Header --#
                                               tags$td(id='left_controls_prerun_header',
                                                       class='controls_header_td controls_narrow header_color collapsible',
                                                       tags$div(class='controls_narrow', 
                                                                "Select Intervention"
                                                       )),
                                               
                                               #-- The Main Panel --#
                                               tags$td(class='display_td content_color', id='display_prerun_td',
                                                       rowspan=2,
                                                       tags$div(class='display',
                                                                create.display.panel('prerun')),
                                                       
                                                       #-- ACCORDION BUTTONS --#
                                                       make.accordion.button('prerun_collapse_left', 
                                                                             left.offset ='-10px',
                                                                             direction='left',
                                                                             hide.ids=c('prerun_collapse_left'),
                                                                             show.ids='prerun_expand_left',
                                                                             remove.class.ids=c('left_controls_prerun','left_prerun_cta','left_prerun_cta_text','left_controls_prerun_header'),
                                                                             add.class.ids=c('left_controls_prerun','left_prerun_cta','left_prerun_cta_text','left_controls_prerun_header'),
                                                                             remove.classes='controls_narrow',
                                                                             add.classes='collapsed',
                                                                             shiny.ids='left_width_prerun',
                                                                             shiny.values=0,
                                                                             visible=T
                                                       ),
                                                       make.accordion.button('prerun_collapse_right', 
                                                                             right.offset ='-10px',
                                                                             direction='right',
                                                                             show.ids=c('prerun_expand_right','custom_expand_right'),
                                                                             hide.ids=c('prerun_collapse_right','custom_collapse_right'),
                                                                             remove.class.ids=c('right_controls_prerun','right_prerun_cta','right_controls_prerun_header'),
                                                                             add.class.ids=c('right_controls_prerun','right_prerun_cta','right_controls_prerun_header'),
                                                                             remove.classes='controls_narrow',
                                                                             add.classes='collapsed',
                                                                             shiny.ids=c('right_width_prerun'),
                                                                             shiny.values=0,
                                                                             visible=F
                                                       )
                                               ),
                                               
                                               #-- Right Header --#
                                               tags$td(id='right_controls_prerun_header',
                                                       class='controls_header_td header_color collapsible collapsed',
                                                       tags$div(class='controls_narrow', "Figure Settings"))
                                           ), #</tr>
                                           
                                           ##-- CONTROL PANELS --##
                                           tags$tr(
                                               
                                               #-- The Left Panel --#
                                               tags$td(id='left_controls_prerun',
                                                       class='controls_td controls_narrow controls_color collapsible',
                                                       tags$div(class='controls controls_narrow',
                                                                tags$div(
                                                                    create.intervention.aspect.selector('prerun', intervention_aspects),
                                                                    create.target.population.selector('prerun'),
                                                                    create.time.frame.selector('prerun'),
                                                                    create.intensity.selector('prerun')
                                                                )
                                                       )),
                                               
                                               #-- The Right Panel --#
                                               tags$td(id='right_controls_prerun',
                                                       class='controls_td controls_color collapsible collapsed',
                                                       rowspan=2,
                                                       create.plot.control.panel('prerun')
                                               )
                                               
                                           ) #</tr>
                                           
                                )) #</tbody></table>
    
    PRERUN.CONTENT
}

#' Create the intervention aspect selector component
#' @param suffix String suffix for input IDs (e.g., 'prerun')
#' @param aspects List of available intervention aspects
#' @return A shiny UI element for selecting intervention aspects
create.intervention.aspect.selector <- function(suffix, config = CONFIG) {
    id <- paste0("int_aspect_", suffix)
    
    choices <- unname(sapply(config$INTERVENTION_ASPECTS, function(aspect) aspect$label))
    values <- unname(sapply(config$INTERVENTION_ASPECTS, function(aspect) aspect$id))
    
    tags$div(
        radioButtons(
            inputId = id,
            label = 'Which Aspects to Intervene On:',
            choiceNames = choices,
            choiceValues = values,
            selected = 'none'
        ),
        make.popover(
            id,
            title = 'What Should the Intervention Affect?',
            content = "You can choose interventions that affect HIV testing, PrEP among those at risk for HIV acquisition, viral suppression among PWH, participation in needle-exchange programs, MOUDs (medications for opioid use disorder), or combinations of these",
            placement = 'right'
        )
    )
}

#' Create the target population selector component
#' @param suffix String suffix for input IDs (e.g., 'prerun')
#' @return A shiny UI element for selecting target populations
#' @note Only displays when an intervention aspect is selected
create.target.population.selector <- function(suffix, config = CONFIG) {
    id <- paste0("int_tpop_", suffix)
    
    choices <- unname(sapply(config$POPULATION_GROUPS, function(pop) pop$label))
    values <- unname(sapply(config$POPULATION_GROUPS, function(pop) pop$id))
    
    # Create a conditional panel that only shows when an aspect (not 'none') is selected
    conditionalPanel(
        condition = paste0("input.int_aspect_", suffix, " !== 'none'"),
        tags$div(
            radioButtons(
                inputId = id,
                label = 'Target Population:',
                choiceNames = choices,
                choiceValues = values,
                selected = 'all'
            ),
            make.popover(
                id,
                title = 'Which Groups to Target?',
                content = "Select whether to apply interventions across all populations or target specific demographic or risk groups.",
                placement = 'right'
            )
        )
    )
}

#' Create the time frame selector component
#' @param suffix String suffix for input IDs (e.g., 'prerun')
#' @return A shiny UI element for selecting intervention time frames
#' @note Only displays when both aspect and population are selected
#' Create the time frame selector component
create.time.frame.selector <- function(suffix, config = CONFIG) {
    id <- paste0("int_timeframe_", suffix)
    
    choices <- unname(sapply(config$TIMEFRAMES, function(tf) tf$label))
    values <- unname(sapply(config$TIMEFRAMES, function(tf) tf$id))
    
    # Show only when both aspect and population are selected
    conditionalPanel(
        condition = paste0("input.int_aspect_", suffix, " !== 'none' && input.int_tpop_", suffix, " !== ''"),
        tags$div(
            radioButtons(
                inputId = id,
                label = 'Intervention Roll-Out Period:',
                choiceNames = choices,
                choiceValues = values,
                selected = '2024_2025'
            ),
            make.popover(
                id,
                title = 'When to Roll Out the Intervention?',
                content = "Select the time period over which the intervention will be implemented. Longer periods allow for more gradual implementation.",
                placement = 'right'
            )
        )
    )
}

#' Create the intervention intensity selector component
#' @param suffix String suffix for input IDs (e.g., 'prerun')
#' @return A shiny UI element for selecting intervention intensity
#' @note Only displays when all previous selections (aspect, population, time frame) are made
create.intensity.selector <- function(suffix, config = CONFIG) {
    id <- paste0("int_intensity_", suffix)
    
    choices <- unname(sapply(config$INTENSITIES, function(int) int$label))
    values <- unname(sapply(config$INTENSITIES, function(int) int$id))
    
    # Show only when all previous selections are made
    conditionalPanel(
        condition = paste0(
            "input.int_aspect_", suffix, " !== 'none' && ",
            "input.int_tpop_", suffix, " !== '' && ",
            "input.int_timeframe_", suffix, " !== ''"
        ),
        tags$div(
            radioButtons(
                inputId = id,
                label = 'Intervention Intensity:',
                choiceNames = choices,
                choiceValues = values,
                selected = 'moderate'
            ),
            make.popover(
                id,
                title = 'How Intensive Should the Intervention Be?',
                content = "Select the level of coverage increase to model. More aggressive increases require more resources but may have larger impacts.",
                placement = 'right'
            )
        )
    )
}
