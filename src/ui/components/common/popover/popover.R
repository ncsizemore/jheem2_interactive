# src/ui/components/common/popover/popover.R
library(shinyBS)

#' Create a popover element
#' @param id Element ID
#' @param title Popover title
#' @param content Popover content
#' @param placement Placement direction (top, right, bottom, left)
#' @param trigger Trigger type (hover, click, focus)
#' @return Popover element
make_popover <- function(id,
                         title,
                         content,
                         placement = "right",
                         trigger = "hover") {
    shinyBS::bsPopover(
        id,
        title = paste0("<b>", title, "</b>"),
        content = content,
        trigger = trigger,
        placement = placement,
        options = list(container = "body", html = TRUE)
    )
}

#' Create a tab popover
#' @param tab_id Tab ID
#' @param title Popover title
#' @param content Popover content
#' @param placement Placement direction
#' @return Tab popover element
make_tab_popover <- function(tab_id,
                             title,
                             content,
                             placement = "bottom") {
    make_popover(tab_id, title, content, placement)
}
