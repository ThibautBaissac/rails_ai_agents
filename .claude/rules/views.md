---
globs: "app/views/**/*.erb, app/components/**/*.rb, app/components/**/*.erb, spec/components/**/*.rb, app/presenters/**/*.rb, spec/presenters/**/*.rb"
---

# View & Component Conventions

- Use ViewComponents (`app/components/`) for reusable UI elements over partials
- Use presenters (`app/presenters/`) with SimpleDelegator for formatting logic
- No business logic in views -- use presenters for display formatting
- Turbo Frames for partial page updates; Turbo Streams for multi-target updates
- Stimulus controllers for client-side behavior (minimal JS, progressive enhancement)
- Tailwind CSS 4 utility classes for styling
- Always include ARIA attributes for accessibility (WCAG 2.1 AA)
