---
paths:
  - "app/views/**/*.erb"
  - "app/javascript/**/*.js"
---

# View & Frontend Conventions (37signals)

- Turbo Streams for real-time updates (append, prepend, replace, remove, morph)
- Turbo Frames for partial page updates and lazy loading
- Stimulus controllers for JS sprinkles (most under 50 lines)
- No React, Vue, Alpine, or other JS frameworks -- Turbo is sufficient
- Server is source of truth; no client-side state management
- Importmap for JS dependencies, no Node.js bundler
- `respond_to` with `format.turbo_stream` and `format.html` in controllers
- Action Text for rich text editing
- Active Storage for file uploads
