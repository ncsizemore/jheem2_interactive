#' Contact form handler
#' Provides functionality for validating and processing contact form submissions
#'
#' @description
#' This module contains framework-agnostic validation and email sending
#' functionality for the contact form, with thin adapter layers for Shiny.
#'
#' For detailed documentation, see README_CONTACT_FORM.md in the project root.
#'
#' Configuration:
#' - EMAIL_USERNAME: Email address to send from (default: jheem.jhu@gmail.com)
#' - EMAIL_PASSWORD: App password for Gmail authentication
#' - CONTACT_EMAIL: Email address to receive messages (default: jheem.jhu@gmail.com)

# Check if blastula is available, provide a fallback if not
has_blastula <- requireNamespace("blastula", quietly = TRUE)
if (!has_blastula) {
  warning("blastula package not found. Email functionality will be limited.")
}

#' Validates contact form input
#' @param name Name input value
#' @param email Email input value
#' @param message Message input value
#' @return List with validation result and message
validate_contact_form <- function(name, email, message) {
  # Empty field checks
  if (is.null(name) || nchar(trimws(name)) == 0) {
    return(list(valid = FALSE, field = "name", message = "Please enter your name"))
  }
  
  if (is.null(email) || nchar(trimws(email)) == 0) {
    return(list(valid = FALSE, field = "email", message = "Please enter your email address"))
  }
  
  if (is.null(message) || nchar(trimws(message)) == 0) {
    return(list(valid = FALSE, field = "message", message = "Please enter a message"))
  }
  
  # Email format validation
  if (!is_valid_email(email)) {
    return(list(valid = FALSE, field = "email", message = "Please enter a valid email address"))
  }
  
  # All validations passed
  list(valid = TRUE, message = NULL)
}

#' Validates email format
#' @param email Email address to validate
#' @return TRUE if email format is valid
is_valid_email <- function(email) {
  grepl("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", email)
}

#' Composes an email message from contact form data
#' @param name Sender's name
#' @param email Sender's email
#' @param message Message content
#' @return Formatted email body
compose_email_body <- function(name, email, message) {
  sprintf("
    Name: %s
    Email: %s
    
    Message:
    %s
  ", name, email, message)
}

#' Sends an email using available email service
#' @param name Sender's name
#' @param email Sender's email
#' @param message Message content
#' @param to_email Recipient email address(es)
#' @param from_email From email address
#' @param subject Email subject
#' @return List with success status and any error message
send_contact_email <- function(name, email, message, 
                              to_email = NULL, 
                              from_email = NULL, 
                              subject = NULL) {
  
  # Default values if not provided
  to_email <- to_email %||% Sys.getenv("CONTACT_EMAIL", "jheem.jhu@gmail.com")
  from_email <- from_email %||% Sys.getenv("EMAIL_USERNAME")
  subject <- subject %||% paste0("JHEEM Website Contact from: ", name)
  
  # Prepare email body
  email_body <- compose_email_body(name, email, message)
  
  # Try to send email
  tryCatch({
    if (has_blastula) {
      # Use blastula if available
      email_obj <- blastula::compose_email(body = email_body)
      
      blastula::smtp_send(
        email = email_obj,
        to = to_email,
        from = from_email,
        subject = subject,
        credentials = blastula::creds_envvar(
          user = from_email,
          pass_envvar = "EMAIL_PASSWORD",
          provider = "gmail",
          host = "smtp.gmail.com",
          port = 465,
          use_ssl = TRUE
        )
      )
    } else {
      # Fallback to base R email if blastula is not available
      # This is less reliable but better than nothing
      mail_result <- try(
        sendmail::sendmail(
          from = from_email,
          to = to_email,
          subject = subject,
          msg = email_body,
          control = list(
            smtpServer = "smtp.gmail.com",
            port = 465,
            user = from_email,
            pass = Sys.getenv("EMAIL_PASSWORD"),
            ssl = TRUE
          )
        )
      )
      
      if (inherits(mail_result, "try-error")) {
        stop("Email sending failed: ", mail_result)
      }
    }
    
    # Return success
    list(success = TRUE, message = "Message sent successfully")
  }, error = function(e) {
    # Log the error with detailed information
    error_msg <- paste("Error sending email:", e$message)
    print(error_msg)  # Basic logging
    
    # Return error information
    list(success = FALSE, message = "Failed to send email. Please try again later.", error = e$message)
  })
}

#' Shiny-specific handler for contact form
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @export
initialize_contact_handler <- function(input, output, session) {
  ns <- session$ns
  
  # Handle form submission
  observeEvent(input$feedback_submit, {
    # Collect form data
    form_data <- list(
      name = input$feedback_name,
      email = input$feedback_email,
      message = input$feedback_contents
    )
    
    # Validate form
    validation <- validate_contact_form(
      form_data$name, 
      form_data$email, 
      form_data$message
    )
    
    if (!validation$valid) {
      # Show validation error using Shiny's notification system
      showNotification(
        validation$message,
        type = "error",
        duration = 5
      )
      return()
    }
    
    # Show sending indicator
    withProgress(
      message = "Sending message...",
      value = 0.5, {
        # Try to send email
        result <- send_contact_email(
          form_data$name,
          form_data$email,
          form_data$message
        )
        
        # Handle result
        if (result$success) {
          # Show success message
          showNotification(
            "Your message has been sent successfully.",
            type = "message",
            duration = 5
          )
          
          # Clear form fields
          updateTextInput(session, "feedback_name", value = "")
          updateTextInput(session, "feedback_email", value = "")
          updateTextAreaInput(
            session,
            "feedback_contents",
            value = "",
            placeholder = "Your feedback, comments, questions, or requests"
          )
        } else {
          # Show error message
          showNotification(
            paste("Failed to send message:", result$message),
            type = "error",
            duration = 8
          )
        }
      }
    )
  })
}

# Null coalescing operator for R versions that don't have it
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
