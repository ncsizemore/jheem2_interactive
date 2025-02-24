
make.accordion.button <- function(id,
                                  show.ids=NULL,
                                  hide.ids=id,
                                  remove.class.ids=NULL,
                                  remove.classes=NULL,
                                  add.class.ids=NULL,
                                  add.classes=NULL,
                                  shiny.ids=NULL,
                                  shiny.values=NULL,
                                  direction=c('right','left')[1],
                                  right.offset=NULL,
                                  left.offset=NULL,
                                  inputId = NULL,
                                  input.value = NULL,
                                  height='30px',
                                  visible=T)
{
    # if (id=='prerun_collapse_right') browser()
    #-- Set up the Chevron --#
    if (direction=='right')
        chevron.class = 'chevron_right'
    else
        chevron.class = 'chevron_left'
    
    
    #-- Set up the style attribute --#
    style = paste0("font-size: ", height, "; ")
    if (!is.null(right.offset))
        style = paste0(style, "right: ", right.offset, "; ")
    if (!is.null(left.offset))
        style = paste0(style, "left: ", left.offset, "; ")
    if (!visible)
        style = paste0(style, "display: none; ")
    
    
    make.accordion.div(class='accordion_button accordion_trigger',
                       id=id,
                       style=style,
                       tags$div(class=chevron.class),
                       #the data attributes
                       show.ids=show.ids,
                       hide.ids=hide.ids,
                       remove.class.ids=remove.class.ids,
                       remove.classes=remove.classes,
                       add.class.ids=add.class.ids,
                       add.classes=add.classes,
                       shiny.ids=shiny.ids,
                       shiny.values=shiny.values)
}

make.accordion.div <- function(...,
                               show.ids=NULL,
                               hide.ids=id,
                               remove.class.ids=NULL,
                               remove.classes=NULL,
                               add.class.ids=remove.class.ids,
                               add.classes=NULL,
                               shiny.ids=NULL,
                               shiny.values=NULL)
{
    rv = tags$div(...)
    add.accordion.attributes(rv,
                             show.ids=show.ids,
                             hide.ids=hide.ids,
                             remove.class.ids=remove.class.ids,
                             remove.classes=remove.classes,
                             add.class.ids=add.class.ids,
                             add.classes=add.classes,
                             shiny.ids=shiny.ids,
                             shiny.values=shiny.values)
}

add.accordion.attributes <- function(target.tag,
                                     show.ids=NULL,
                                     hide.ids=NULL,
                                     remove.class.ids=NULL,
                                     remove.classes=NULL,
                                     add.class.ids=remove.class.ids,
                                     add.classes=NULL,
                                     shiny.ids=NULL,
                                     shiny.values=NULL)
{
    #-- Set up the data attributes --#
    
    if (!is.null(show.ids))
        target.tag = tagAppendAttributes(target.tag,
                                         "data-show_targets" = paste0(show.ids, collapse=';'))
    
    if (!is.null(hide.ids))
        target.tag = tagAppendAttributes(target.tag,
                                         "data-hide_targets" = paste0(hide.ids, collapse=';'))
    
    if (!is.null(remove.class.ids))
    {
        if (!is.null(remove.classes) && length(remove.classes)==1)
            remove.classes = rep(remove.classes, length(remove.class.ids))
        
        if (is.null(remove.classes) || length(remove.classes) != length(remove.class.ids))
            stop("remove.classes must have the same length as remove.class.ids")
        
        target.tag = tagAppendAttributes(target.tag,
                                         "data-remove_class_targets" = paste0(remove.class.ids, collapse=';'),
                                         "data-remove_classes" = paste0(remove.classes, collapse=';'))
    }
    
    if (!is.null(add.class.ids))
    {
        if (!is.null(add.classes) && length(add.classes)==1)
            add.classes = rep(add.classes, length(add.class.ids))
        
        if (is.null(add.classes) || length(add.classes) != length(add.class.ids))
            stop("add.classes must have the same length as add.class.ids")
        
        target.tag = tagAppendAttributes(target.tag,
                                         "data-add_class_targets" = paste0(add.class.ids, collapse=';'),
                                         "data-add_classes" = paste0(add.classes, collapse=';'))
    }
    
    if (!is.null(shiny.ids))
    {
        if (!is.null(shiny.values) && length(shiny.values)==1)
            shiny.values = rep(shiny.values, length(shiny.ids))
        
        if (is.null(shiny.values) || length(shiny.values) != length(shiny.ids))
            stop("shiny.values must have the same length as shiny.ids")
        
        target.tag = tagAppendAttributes(target.tag,
                                         "data-shiny_targets" = paste0(shiny.ids, collapse=';'),
                                         "data-shiny_values" = paste0(shiny.values, collapse=';'))
    }
    
    #-- Return --#
    target.tag
}