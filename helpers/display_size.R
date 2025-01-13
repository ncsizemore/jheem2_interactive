# Code to (roughly) track the size of the display panel using javascript

LEFT.PANEL.SIZE = c(prerun=250,
                    custom=500)
RIGHT.PANEL.SIZE = c(prerun=250,
                     custom=250)

FIGURE.PADDING = 5
DISPLAY_PADDING = 0#10
DISPLAY_Y_CUSHION = 2*DISPLAY_PADDING + 10
DISPLAY_X_CUSHION = 2*DISPLAY_PADDING + 25

get.display.size <- function(input, suffix) {
    size <- input[[paste0('display_size_', suffix)]]
    if (is.null(size)) {
        print("Using default display size")
        size <- list(
            width = DEFAULT.DISPLAY.WIDTH,
            height = DEFAULT.DISPLAY.HEIGHT
        )
    }
    
    # Get panel widths with defaults
    left_width <- input[[paste0('left_width_', suffix)]]
    right_width <- input[[paste0('right_width_', suffix)]]
    
    if (is.null(left_width)) left_width <- LEFT.PANEL.SIZE[suffix]
    if (is.null(right_width)) right_width <- RIGHT.PANEL.SIZE[suffix]
    
    print(paste("Panel widths - Left:", left_width, "Right:", right_width))
    
    # Calculate display width
    size$width <- size$width - 
        as.numeric(left_width) - 
        as.numeric(right_width)
    
    print(paste0(suffix, " final size: width=", size$width, ", height=", size$height))
    size
}