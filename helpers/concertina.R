
make.concertina.button <- function(id,
                                   show.ids=NULL,
                                   hide.ids=id,
                                   target.container.ids=NULL,
                                   remove.classes=NULL, # if finds the i'th class here, removes it and adds the i'th class in the following argument
                                   add.classes=NULL,
                                   shiny.ids=NULL,
                                   shiny.values=NULL,
                                   direction=c('right', 'left')[1],
                                   right.offset=NULL,
                                   left.offset=NULL,
                                   height='30px',
                                   inputId = NULL,
                                   visible=T)
{
    
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
    
    make.concertina.div(class='concertina_button concertina_trigger',
                        id=id,
                        style=style,
                        tags$div(class=chevron.class),
                        #the data attributes
                        show.ids=show.ids,
                        hide.ids=hide.ids,
                        target.container.ids=target.container.ids,
                        remove.classes=remove.classes,
                        add.classes=add.classes,
                        shiny.ids=shiny.ids,
                        shiny.values=shiny.values,
                        inputId=inputId,)
}

make.concertina.div <- function(...,
                                show.ids=NULL,
                                hide.ids=id,
                                target.container.ids=NULL,
                                remove.classes=NULL,
                                add.classes=NULL,
                                shiny.ids=NULL,
                                shiny.values=NULL)
{
    rv = tags$div(...)
    add.concertina.attributes(rv,
                              show.ids=show.ids,
                              hide.ids=hide.ids,
                              target.container.ids=target.container.ids,
                              remove.classes=remove.classes,
                              add.classes=add.classes,
                              shiny.ids=shiny.ids,
                              shiny.values=shiny.values)
}

add.concertina.attributes <- function(target.tag,
                                      show.ids=NULL,
                                      hide.ids=NULL,
                                      target.container.ids=NULL,
                                      remove.classes=NULL,
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
    
    if (!is.null(target.container.ids))
        target.tag = tagAppendAttributes(target.tag,
                                         "target_container_ids" = paste0(target.container.ids, collapse = ';'))
    if (!is.null(remove.classes))
        target.tag = tagAppendAttributes(target.tag,
                                         "remove_classes" = paste0(remove.classes, collapse = ';'))
    if (!is.null(add.classes))
        target.tag = tagAppendAttributes(target.tag,
                                         "add_classes" = paste0(add.classes, collapse = ';'))
    
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
    return(target.tag)
}