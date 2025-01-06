make.custom.content <- function()
{
    WEB.VERSION.DATA.INTERVENTION.LABEL.ARTICLE.TEMP = 'a'
    WEB.VERSION.DATA.INTERVENTION.LABEL.TEMP = 'simset'
    CUSTOM.CONTENT = tags$div(
        id='custom_table', #if change this to "grid", would have to change other places
        class='Andrew_grid Andrew_grid_left_expanded fill_page1', #because I have to to test old window_sizes.js
        # class='display_table fill_page1',
        
        #-- LEFT PANEL --#
        div(class='Andrew_panel Andrew_side_panel Andrew_left_panel', id='display_custom_left',
            
            #-- Left header --#
            div(id='left_controls_custom_header',
                class='Andrew_controls_header header_color',
                div(paste0("Select ", WEB.VERSION.DATA.INTERVENTION.LABEL.TEMP))),

            #-- Left panel controls --#
            div(id='left_controls_custom',
                class='controls_color Andrew_control_panel',
                div(create.simset.selector(suffix='custom'))),

            #-- Left CTA --#
            div(id='left_custom_cta_wrapper',
                class='Andrew_cta_wrapper',
                div(id='left_custom_cta',
                    class='Andrew_cta_container cta_background_color',
                    tags$div(
                        # class='controls_narrow cta_sub_td',
                        actionButton(class='cta cta_color', inputId='run_custom', label='Generate Projections'))
                ),
                div(id='left_custom_cta_text',
                    class='Andrew_cta_text_container cta_background_color',
                    div(class='Andrew_cta_text_sub_container',
                        div(class='cta_text',
                            HTML("This will take 10-30 seconds<BR>
                          <input type='checkbox' id='chime_run_prerun' name='chime_run_prerun' style='float: left'>
                          <label for='chime_run_prerun'>&nbsp;Play a chime when done</label>"))))
                ),
        ),
        
        #-- MAIN PANEL--#
        div(id='display_custom_main',
            class='Andrew_panel Andrew_main_panel content_color',
            
            #-- CONCERTINA BUTTONS --#
            make.concertina.button(id='custom_collapse_left',
                                   left.offset = '-10px',
                                   direction='left',
                                   show.ids='custom_expand_left',
                                   target.container.ids='custom_table',
                                   remove.classes='Andrew_grid_left_expanded Andrew_grid_both_expanded',
                                   add.classes='Andrew_grid_none_expanded Andrew_grid_right_expanded',
                                   shiny.ids ='left_width_custom',
                                   shiny.values=0,
                                   visible=T),
            
            make.concertina.button(id='custom_expand_left',
                                   left.offset='0px',
                                   direction='right',
                                   show.ids='custom_collapse_left',
                                   target.container.ids='custom_table',
                                   remove.classes='Andrew_grid_none_expanded Andrew_grid_right_expanded',
                                   add.classes='Andrew_grid_left_expanded Andrew_grid_both_expanded',
                                   shiny.ids ='left_width_custom',
                                   shiny.values=LEFT.PANEL.SIZE['custom'],
                                   visible=F),
            
            make.concertina.button(id='custom_collapse_right',
                                   right.offset='-10px',
                                   direction='right',
                                   show.ids='custom_expand_right',
                                   target.container.ids='custom_table',
                                   remove.classes='Andrew_grid_right_expanded Andrew_grid_both_expanded',
                                   add.classes='Andrew_grid_none_expanded Andrew_grid_left_expanded',
                                   shiny.ids=c('right_width_custom'),
                                   shiny.values=0,
                                   visible=F),
            
            make.concertina.button(id='custom_expand_right',
                                   right.offset='0px',
                                   direction='left',
                                   show.ids='custom_collapse_right',
                                   target.container.ids='custom_table',
                                   remove.classes='Andrew_grid_none_expanded Andrew_grid_left_expanded',
                                   add.classes='Andrew_grid_right_expanded Andrew_grid_both_expanded',
                                   shiny.ids =c('right_width_custom'),
                                   shiny.values=c(RIGHT.PANEL.SIZE['custom']),
                                   visible=T),
            
            tags$div(class='display', #plus more
                     create.display.panel('custom')),
            
            tags$div(id='under_display_custom',
                     class='content_color',
                     "This is the under display")
            ),
        
        #-- RIGHT PANEL --#
        div(class='Andrew_panel Andrew_side_panel Andrew_right_panel', id='display_custom_right',
            
            #-- Right header --#
            div(id='right_controls_custom_header',
                class='Andrew_controls_header header_color',
                div("Figure Settings")),
            
            #-- Right panel --#
            div(class='controls_color Andrew_control_panel',
                create.plot.control.panel('custom'),
            ),
            
            #-- Right panel button --#
            div(id='right_custom_cta',
                class='Andrew_cta_container cta_background_color',
                div(class='Andrew_cta_sub_container',
                    actionButton(class='cta cta_color', inputId='redraw_custom', label='Adjust Projections')))
        )
           
    )
}