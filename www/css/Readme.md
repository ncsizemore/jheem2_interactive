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
│   │   ├── navigation.css# Panel navigation (toggle buttons)
│   │   └── loading.css   # Loading state styles
│   │
│   ├── controls/       # UI control styles
│   │   ├── base.css     # Base control styles
│   │   ├── plot.css     # Plot control styles
│   │   └── toggle.css   # Toggle button styles
│   │
│   ├── panels/        # Panel-specific styles
│   │   ├── base.css    # Base panel structure
│   │   ├── plot.css    # Plot panel styles
│   │   └── table.css   # Table panel styles
│   │
│   └── feedback/      # User feedback styles
│       ├── errors.css   # Error message styles
│       └── notifications.css # Notification styles
│
├── color_schemes/      # Theme variations
│   ├── _theme_variables.css # Theme-specific variables
│   ├── theme_jh.css        # Johns Hopkins theme
│   ├── theme_modern.css    # Modern theme colors/styles
│   └── color_scheme_grayscale.css # Grayscale theme
│
├── pages/             # Page-specific styles
│   ├── about.css
│   ├── contact.css
│   ├── custom.css     # Custom intervention page
│   ├── overview.css
│   ├── prerun.css     # Pre-run intervention page
│   └── team.css
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
6. Avoid inline styles - use CSS classes instead
7. Keep JavaScript focused on behavior, CSS on presentation

## CSS vs JavaScript Responsibilities

### CSS Handles:
- Visual styling (colors, fonts, spacing)
- Layout and positioning
- Transitions and animations
- State-based styling (hover, active, disabled)
- Responsive design adaptations
- Theme variations

### JavaScript Handles:
- Dynamic state management
- Panel visibility toggling
- User interaction responses
- DOM manipulation
- Event handling
- Data-driven UI updates
- Complex animations
- Conditional rendering

### Current JavaScript Files:
- `js/layout/panel-controls.js`: Manages panel visibility state and toggle buttons
  - Handles left/right panel collapse/expand
  - Updates button icons and positions
  - Manages panel state transitions
  - Notifies Shiny of state changes

Files are being standardized to:
- Use consistent state management patterns
- Remove inline styles in favor of CSS classes
- Separate behavior (JS) from presentation (CSS)
- Share common panel management logic

## Dependencies
- CSS variables defined in `base/variables.css`
- Theme variables in `color_schemes/_theme_variables.css`
- Component styles may depend on base variables
- Layout styles may reference component classes

## Recent Updates
- Moved panel toggle button styles to dedicated navigation.css
- Standardized spacing across pages (custom.css matches prerun.css)
- Removed inline styles in favor of CSS classes
- Improved separation of concerns between JS and CSS
- Added theme variables for consistent styling
