# UI Feedback Components

This directory contains CSS for user feedback components, including errors, notifications, and other user interface signals.

## Error Styling

The `errors.css` file contains styles for the dual-layer error display system:

### Error Types

The styling supports multiple error types:
- Validation errors (form validation)
- Component errors (general component errors)
- Plot errors (visualization-specific errors)

### Severity Levels

Different severity levels have distinct visual styling:
- Warning: Yellow/orange styling for non-critical issues
- Error: Red styling for standard errors
- Fatal: Dark red styling for critical errors

### CSS Structure

The error styling is organized as follows:

1. **Base Structure**
   ```css
   .error-boundary {
       margin: var(--spacing-md) 0;
   }
   ```

2. **Error Type Variants**
   ```css
   .validation-error,
   .component-error,
   .plot-error {
       /* Shared styling for all error types */
   }
   ```

3. **Error Components**
   ```css
   .error-icon { /* Styling for error icons */ }
   .error-message { /* Styling for error messages */ }
   .error-details { /* Styling for additional error details */ }
   ```

4. **Severity Variations**
   ```css
   .validation-error.warning,
   .component-error.warning,
   .plot-error.warning { /* Warning styling */ }

   .validation-error.error,
   .component-error.error,
   .plot-error.error { /* Error styling */ }

   .validation-error.fatal,
   .component-error.fatal,
   .plot-error.fatal { /* Fatal styling */ }
   ```

### Critical Selectors for Error Visibility

Some CSS selectors are critical for error visibility:

```css
/* Simulation error styling with :has() selector */
.plot-error:has([id$="plot_error_message"]:not(:empty)),
.plot-error:has([id$="table_error_message"]:not(:empty)),
.table-error:has([id$="table_error_message"]:not(:empty)) {
    /* Styling for visible errors */
    display: block !important;
    /* Other error styling */
}

/* Fallback for browsers without :has() support */
.main-panel-table .plot-error:not(:empty),
.main-panel-table .table-error:not(:empty),
.main-panel-table .error-display:not(:empty),
.main-panel-plot .plot-error:not(:empty),
.main-panel-plot .error-display:not(:empty) {
    display: block !important;
    visibility: visible !important;
    opacity: 1 !important;
}
```

### Animation

Errors include subtle animations for better user experience:

```css
.error-boundary>div {
    animation: errorFadeIn 0.3s ease-in-out;
}

@keyframes errorFadeIn {
    from {
        opacity: 0;
        transform: translateY(-10px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}
```

### Input Validation States

Special styling for form inputs with validation errors:

```css
.is-invalid {
    border-color: var(--color-error, #dc3545) !important;
    background-color: var(--color-error-bg, #fff3f3) !important;
}

.is-invalid:focus {
    border-color: var(--color-error, #dc3545) !important;
    box-shadow: 0 0 0 0.2rem var(--color-error-shadow, rgba(220, 53, 69, 0.25)) !important;
}

.input-error-message {
    color: var(--color-error, #dc3545);
    font-size: 0.875em;
    margin-top: 0.25rem;
}
```

## Implementation Notes

1. The `:has()` selector is used for targeting error containers with content, but may not be supported in all browsers. The fallback selectors should be maintained.

2. For maximum compatibility, both CSS approaches are used:
   - Specific selectors with `:has()` for modern browsers
   - Generic selectors with `:not(:empty)` for broader support

3. Z-index values ensure errors appear above other UI elements.

4. When modifying error styles, always ensure both the structured boundary errors and direct text errors are properly styled.
