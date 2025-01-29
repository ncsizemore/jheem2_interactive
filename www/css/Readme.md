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
│   └── theme_modern.css # Modern theme colors/styles
│
├── pages/             # Page-specific styles
│   ├── about.css
│   ├── contact.css
│   ├── custom.css
│   ├── overview.css
│   ├── prerun.css
│   └── team.css
│
└── main.css          # Main CSS file that imports all others
```