# Contact Page

This directory contains the components needed to render the contact page of the JHEEM application. The contact page allows users to send messages to the JHEEM team through a simple form interface.

## Files Overview

- **contact.R**: Main entry point for the contact page, loads configuration and renders the content
- **content.R**: Creates the page layout and containers for the contact form
- **form.R**: Implements the contact form UI elements based on configuration

## Configuration

The contact form is configured through YAML files, allowing for easy customization without code changes.

### Main Configuration File

The contact form uses configuration from `src/ui/config/pages/contact.yaml` which defines:

- Page title and description
- Form fields and their properties
- Layout and styling options

Example configuration:

```yaml
# Contact page configuration
page:
  title: "Contact Us"
  subtitle: "Get in Touch with the JHEEM Team"
  description: "We welcome any feedback, comments, questions, or requests"

form:
  fields:
    name:
      label: "Your name"
      type: "text"
      placeholder: "Enter your name"
      required: true
    
    email:
      label: "Your email"
      type: "email"
      placeholder: "Enter your email address"
      required: true
    
    message:
      label: "Your message"
      type: "textarea"
      placeholder: "Your feedback, comments, questions, or requests"
      required: true
      rows: 10

  submit:
    label: "Submit"
    class: "btn btn-primary"
```

## Customizing the Contact Form

To modify the contact form:

1. **Change Field Labels/Placeholders**: Edit the `label` and `placeholder` properties in the YAML file
2. **Change Form Appearance**: Modify the `class` and other style properties in the YAML
3. **Add New Fields**: Add new field definitions to the YAML configuration

## Email Configuration

The contact form sends emails using credentials specified in environment variables. To configure the email functionality:

1. **Create Environment Variables**:
   - `EMAIL_USERNAME`: Email account used to send messages (typically jheem.jhu@gmail.com)
   - `EMAIL_PASSWORD`: App password for the email account
   - `CONTACT_EMAIL`: Destination for form submissions (typically jheem.jhu@gmail.com)

2. **For Local Development**:
   - Create a `.Renviron` file in the project root:
     ```
     EMAIL_USERNAME=jheem.jhu@gmail.com
     EMAIL_PASSWORD=your-app-password
     CONTACT_EMAIL=jheem.jhu@gmail.com
     ```
   - Restart R session to load the new environment variables

3. **For ShinyApps.io Deployment**:
   - Add these same environment variables in the ShinyApps.io dashboard
   - Go to your app's settings page
   - Find the "Environment Variables" section
   - Add each variable with its value

## How the Form Works

When a user submits the contact form:

1. Client-side validation ensures all required fields are filled
2. Server-side validation checks email format and content
3. If valid, an email is sent to the configured CONTACT_EMAIL address
4. The email contains the user's name, email, and message
5. Success notification is shown to the user
6. Form fields are cleared for a new submission

## Form Handler

The contact form's backend functionality is implemented in:
```
/src/ui/handlers/contact_handler.R
```

This handler provides:
- Form validation
- Email sending via the blastula package
- Error handling and user feedback

For technical details on the handler implementation, see the README in the handlers directory.

## Troubleshooting

If the contact form isn't working:

1. **Verify Email Credentials**:
   - Check that environment variables are set correctly
   - Ensure the app password is correct
   - Verify the Gmail account has 2-Step Verification enabled

2. **Check Required Packages**:
   - Run `install_dependencies.R` to ensure blastula is installed
   - Check for any console errors related to missing packages

3. **Test Form Submission**:
   - Check for validation error messages
   - Look for success/error notifications
   - Check the jheem.jhu@gmail.com inbox for test messages
