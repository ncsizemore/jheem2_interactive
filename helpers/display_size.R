# Code to (roughly) track the size of the display panel using javascript

LEFT.PANEL.SIZE = c(prerun=250,
                    custom=500)
RIGHT.PANEL.SIZE = c(prerun=250,
                     custom=250)

FIGURE.PADDING = 5
DISPLAY_PADDING = 0#10
DISPLAY_Y_CUSHION = 2*DISPLAY_PADDING + 10
DISPLAY_X_CUSHION = 2*DISPLAY_PADDING + 25

get.display.size <- function(input, suffix)
{
    size = input[[paste0('display_size_', suffix)]]
    print(paste0('input$left_width_', suffix, '=', input[[paste0('left_width_', suffix)]]))
    print(paste0('input$right_width_', suffix, '=', input[[paste0('right_width_', suffix)]]))
    
    size$width = size$width -
        as.numeric(input[[paste0('left_width_', suffix)]]) -
        as.numeric(input[[paste0('right_width_', suffix)]])
    
    print(paste0(suffix, " size: ", paste0(size, collapse=', ')))
    # browser()
    size
}