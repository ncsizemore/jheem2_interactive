
##---------------##
##-- TOOL-TIPS --##
##---------------##

OVERVIEW.POPOVER.TITLE = 'What this Site is About'
OVERVIEW.POPOVER = "We apply the JHEEM model of HIV transmission to the Ending the HIV Epidemic Initiative"

FAQ.POPOVER.TITLE = "Frequently Asked Questions"
FAQ.POPOVER = "Answers to common questions about our model and its application here."

ABOUT.POPOVER.TITLE = "The Model Behind the Projections"
ABOUT.POPOVER = "A brief overview of the Johns Hopkins Epidemiologic and Economic Model of HIV (JHEEM) and the methods we use to calibrate it."

OUR.TEAM.POPOVER.TITLE = "The Research Team"
OUR.TEAM.POPOVER = "About the investigators behind the Johns Hopkins Epidemiologic and Economic Model of HIV (JHEEM)."

CONTACT.POPOVER.TITLE = "Contact Us"
CONTACT.POPOVER = "Send us a message with any questions, feedback, or suggestions."


# NB: these popover depends on a javascript hack to set the id of the title text, in setup_tooltips.js
make.tab.popover <- function(id,
                             title,
                             content)
{
    shinyBS::bsPopover(id, 
                       title=paste0("<b>", title, "</b>"),
                       content=content,
                       trigger = "hover",
                       placement='bottom',
                       options=list(container="body", html=T))
}

make.popover <- function(id,
                         title,
                         content,
                         placement)
{
    shinyBS::bsPopover(id, 
                       title=paste0("<b>", title, "</b>"),
                       content=content,
                       trigger = "hover",
                       placement=placement,
                       options=list(container="body", html=T))
}