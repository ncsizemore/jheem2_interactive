# CSS Structure

## Organization
The CSS is organized into the following structure:

```
css/
├── base/                 # Foundation styles
│   └── variables.css     # CSS custom properties/design tokens
│
├── layout/              # Layout-specific styles
│   └── three-panel.css  # Three-panel layout structure
│
├── components/          # Reusable component styles
│   ├── common/         # Shared component styles
│   │   ├── panels.css    # Panel structure and styling
│   │   ├── scrollbars.css# Custom scrollbar styling
│   │   └── loading.css   # Loading state styles
│   │
│   ├── controls/       # UI control styles
│   │   └── toggle.css    # Toggle button styles
│   │
│   └── ...            # Other component-specific styles
│
├── color_schemes/      # Theme variations
│   └── color_scheme_jh.css
│
├── pages/             # Page-specific styles
│   ├── about.css
│   ├── contact.css
│   ├── custom.css
│   ├── overview.css
│   └── prerun.css
│
└── main.css          # Main CSS file that imports all others
```

## Usage
- `base/`: Contains foundational styles and variables that are used throughout the application
- `layout/`: Contains structural layout styles that define the major sections of the application
- `components/`: Contains styles for reusable UI components, organized by type
- `color_schemes/`: Contains theme-specific color and style overrides
- `pages/`: Contains styles specific to individual pages

## Best Practices
1. Use CSS variables from `variables.css` for consistent styling
2. Keep component styles modular and reusable
3. Maintain separation between layout and component styles
4. Use semantic class names
5. Follow existing patterns for new components

## Dependencies
- CSS variables defined in `base/variables.css`
- Component styles may depend on base variables
- Layout styles may reference component classes