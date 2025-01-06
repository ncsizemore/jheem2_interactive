
CONTACT.EMAILS = c('anthony.fojo@jhmi.edu')#,'jflack1@jhu.edu')

add.contact.handlers <- function(session, input, output)
{
    # Contact form ####
    observeEvent(input[['feedback_submit']], {
        tryCatch({
            name = input[['feedback_name']]
            email = input[['feedback_email']]
            contents = input[['feedback_contents']]
            
            if (email=='')
                show.warning.message(session,
                                   title='E-mail Address Missing',
                                   message = "Your e-mail address cannot be blank")
            else if (!is.valid.email(email))
                show.warning.message(session,
                                   title='Invalid E-mail Address',
                                   message = paste0("'", email, "' is not a valid e-mail address."))
            else if (name=='')
                show.warning.message(session,
                                   title='Name Missing',
                                   message = "Please enter your name")
            else if (contents=='')
                show.warning.message(session,
                                   title='Message Missing',
                                   message = "Please enter a message to send")
            else
            {
                # https://r-bar.net/mailr-smtp-webmail-starttls-tls-ssl/#majorHosts
                # https://www.r-bloggers.com/2019/04/mailr-smtp-setup-gmail-outlook-yahoo-starttls/
                # TODO: Handle validation for email addresses, e.g.:
                # Warning: Error in .jcall: org.apache.commons.mail.EmailException: 
                # javax.mail.internet.AddressException: Missing final '@domain' in string
                #  ``askjdfkljfalmvlkgjlkaj''
                #  Warning: Error in .jcall: org.apache.commons.mail.EmailException: 
                #  javax.mail.internet.AddressException: Domain contains illegal character 
                #  in string ``kfjasklklfjlk@lksdjfkldsjfkl@lkdjfjkljlkj''
                
                
                show_modal_spinner(session=session,
                                   text=HTML('<div class="uploading_custom"><h1>Sending message...</h1></div>'),
                                   spin='bounce')

                #JP Converting from mailR to blastula
                
                email.body <- paste0(
                        # Keep indented like this for email formatting purposes.
                        'Name: ', name, '
        Email: ', email, '
        Contents: 
        ', contents)

                email.account <- Sys.getenv("EMAIL_USERNAME")

                smtp_send(
                    email = compose_email(body = email.body),
                    to = CONTACT.EMAILS,
                    from = email.account,
                    subject = paste0('EndingHIV email from: ', name),
                    credentials = creds_envvar(
                        user = email.account,
                        #creds_envvar uses Sys.getenv(pass_envvar) internally
                        pass_envvar = "EMAIL_PASSWORD",
                        provider = "gmail",
                        host = "smtp.gmail.com",
                        port=465,
                        use_ssl=T
                    )
                )
                
                # Warning: Error in : FATAL:  no pg_hba.conf entry for host 
                # "73.135.116.183", user "jklcmyywfuzgrf", database "d7kjdf34erfuu8", 
                # SSL off
                # db.write.contactForm(
                #   name=name, email=email, message=contents)
                
                # pop a confirm message and clear the inputs
                
                remove_modal_spinner(session)
                show.success.message(session,
                                     title='Message Sent',
                                     message="Your message was sent successfully")

                updateTextAreaInput(session,
                                    inputId = 'feedback_contents',
                                    value='',
                                    placeholder="Your feedback, comments, questions, or requests")
            }
        },
       error = function(e){
           
           remove_modal_spinner(session)
           log.error(e)
           show.error.message(session, 
                              title="Error Sending Message",
                              message = "There was an error sending your message. We apologize. Please try again after a few minutes.")
       })
    })
}


is.valid.email <- function(x) 
{
    grepl("\\<[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\>", as.character(x), ignore.case=TRUE)
}
