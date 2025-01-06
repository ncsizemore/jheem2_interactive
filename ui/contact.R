

CONTACT.CONTENT = tags$div(
    tags$div(style='height: 25px'),
    tags$div(class='contact',
             tags$table(
                 tags$tr(
                     tags$td(colspan='2', class='contact_header header_color',
                             tags$h1("Contact Us")
                     )
                 ), #</tr>
                 tags$tr(
                     tags$td(colspan='2',
                             tags$p("We welcome any feedback, comments, questions, or requests")
                     )
                 ), #</tr>
                 tags$tr(
                     tags$td(
                         fluidRow(
                             textInput(
                                 inputId='feedback_name', 
                                 label='Your name') ),
                         fluidRow(
                             textInput(
                                 inputId='feedback_email', 
                                 label='Your email') )
                     ), #</td>
                     tags$td(
                         textAreaInput(
                             inputId='feedback_contents', 
                             label='Your message',
                             placeholder="Your feedback, comments, questions, or requests",
                             height='250px',
                             width='375px',
                             # cols=80,
                             # rows=6,
                         )
                     )
                 ),
                 
                 tags$tr(
                     tags$td(colspan='2', style='text-align: center',
                             actionButton(class='cta cta_color',
                                          inputId='feedback_submit',
                                          label='Submit'),
                             
                             tags$div(style='height:20px')
                     )
                 )
             ))
)

CONTACT.CONTENT = HTML(paste0("<center>", CONTACT.CONTENT, "</center>"))