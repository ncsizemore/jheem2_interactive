# UI Handlers

This directory contains framework-agnostic handlers for UI components that require complex behaviors.

## Contact Handler

The contact handler (`contact_handler.R`) provides functionality for:

1. Validating contact form input
2. Sending emails via the blastula package
3. Providing fallback mechanisms when dependencies aren't available
4. Framework-agnostic core functionality with thin Shiny-specific adapters

### Technical Implementation

The contact handler follows a modular, framework-agnostic approach:

- **Core Functions**: Pure functions for validation, email composition, and sending
- **Adapter Layer**: Thin Shiny-specific code that connects UI events to core functions
- **Graceful Degradation**: Fallbacks when dependencies aren't available

Key functions:

```r
# Core validation (framework-agnostic)
validate_contact_form(name, email, message)

# Email sending (framework-agnostic)
send_contact_email(name, email, message, to_email, from_email, subject)

# Shiny-specific adapter
initialize_contact_handler(input, output, session)
```

### Configuration

To use the contact form, you need to configure email credentials using environment variables:

```
# In .Renviron file (local development)
EMAIL_USERNAME=jheem.jhu@gmail.com
EMAIL_PASSWORD=your-app-password
CONTACT_EMAIL=jheem.jhu@gmail.com
```

For ShinyApps.io deployment:
1. Go to the ShinyApps.io dashboard
2. Navigate to your app's settings
3. Add the above environment variables with appropriate values

### Creating a Gmail App Password

1. Sign in to the Gmail account
2. Go to [Google Account Security](https://myaccount.google.com/security)
3. Enable 2-Step Verification if not already enabled
4. Under "App passwords", create a new app password
5. Name it "JHEEM Web App" (or similar)
6. Copy the generated password (remove spaces)
7. Add to your .Renviron file and ShinyApps.io settings

### Dependencies

The contact form requires the blastula package for email functionality:

```r
install.packages("blastula")
```


### Testing

To test the contact form:

1. Ensure environment variables are set
2. Navigate to the Contact Us page
3. Fill out and submit the form
4. Check for success notification
5. Verify email arrives at CONTACT_EMAIL address

### Troubleshooting

Common issues:

- **Authentication errors**: Check app password is correct
- **Missing package**: Install blastula
- **Environment variables**: Restart R session to load .Renviron changes
- **Gmail restrictions**: Ensure account allows less secure apps

### Future Considerations

- The handler is designed to be framework-agnostic to support future migration
- Email sending is abstracted to allow different implementations
- Validation is separated from UI to support different frameworks
