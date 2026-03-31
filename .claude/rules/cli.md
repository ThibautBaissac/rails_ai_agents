# CLI Commands

## Development Server
```bash
bin/dev                                          # Start all services (Foreman/Procfile.dev)
bin/rails server                                 # Rails only (port 3000)
bin/rails server -p 4000                         # Custom port
bin/rails server -b 0.0.0.0                      # Bind to all interfaces
lsof -i :3000                                    # Check what's using port 3000
kill -9 $(lsof -t -i :3000)                      # Force kill process on port 3000
cat tmp/pids/server.pid                          # Show stored server PID
rm tmp/pids/server.pid                           # Remove stale PID file
```

## Tests (RSpec)
```bash
bundle exec rspec                                # Full suite
bundle exec rspec spec/models/                   # Directory
bundle exec rspec spec/models/user_spec.rb       # Single file
bundle exec rspec spec/models/user_spec.rb:25    # Single example (line)
bundle exec rspec --fail-fast                    # Stop on first failure
bundle exec rspec --only-failures                # Re-run failures
bundle exec rspec --format documentation         # Verbose output
```

## Linting (RuboCop)
```bash
bundle exec rubocop -a                           # Auto-fix safe cops
bundle exec rubocop -A                           # Auto-fix all (including unsafe)
bundle exec rubocop app/models/                  # Specific directory
bundle exec rubocop --only Style/StringLiterals   # Single cop
```

## Security
```bash
bin/brakeman --no-pager                          # Static analysis
bundle exec bundler-audit check --update         # Gem vulnerabilities
```

## Database
```bash
bin/rails db:create                              # Create database
bin/rails db:migrate                             # Run pending migrations
bin/rails db:rollback                            # Undo last migration
bin/rails db:rollback STEP=3                     # Undo last 3 migrations
bin/rails db:migrate:status                      # Show migration status
bin/rails db:seed                                # Run seeds
bin/rails db:reset                               # Drop, create, migrate, seed
bin/rails db:schema:load                         # Load schema.rb (skip migrations)
```

## Generators
```bash
bin/rails g model User name:string email:string  # Model + migration + factory
bin/rails g migration AddRoleToUsers role:integer # Migration only
bin/rails g controller Users index show           # Controller + views + routes
bin/rails destroy model User                      # Undo generator
```

## Rails Console
```bash
bin/rails console                                # IRB with app loaded
bin/rails console --sandbox                      # Auto-rollback on exit
bin/rails routes                                 # All routes
bin/rails routes -g user                         # Filter routes by pattern
```

## Solid Queue (Background Jobs)
```bash
bin/rails solid_queue:start                      # Start queue worker
```

## Assets & Dependencies
```bash
bundle install                                   # Install gems
bundle update <gem>                              # Update specific gem
bin/importmap pin <package>                      # Add JS dependency
bin/importmap unpin <package>                    # Remove JS dependency
```

## Debugging
```bash
bin/rails runner "puts User.count"               # Run one-off script
bin/rails dbconsole                              # Direct database CLI (psql)
bin/rails middleware                              # List middleware stack
bin/rails stats                                  # Code statistics
```
