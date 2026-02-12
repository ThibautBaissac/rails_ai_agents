# Claude Code Setup Plan for rails-claude

> Detailed implementation plan for configuring Claude Code V4 with this Rails 8 project.

---

## Table of Contents

1. [Project Analysis](#project-analysis)
2. [Phase 1: Global Configuration](#phase-1-global-configuration)
3. [Phase 2: Project CLAUDE.md](#phase-2-project-claudemd)
4. [Phase 3: Security Hooks](#phase-3-security-hooks)
5. [Phase 4: Custom Commands](#phase-4-custom-commands)
6. [Phase 5: Skills](#phase-5-skills)
7. [Phase 6: Custom Agents](#phase-6-custom-agents)
8. [Phase 7: MCP Servers](#phase-7-mcp-servers)
9. [Implementation Checklist](#implementation-checklist)

---

## Project Analysis

### Current Stack

| Component | Technology |
|-----------|------------|
| **Ruby** | 3.3.6 |
| **Rails** | 8.2.0.alpha (main branch) |
| **Database** | SQLite 3 |
| **Testing** | Minitest + Capybara + Selenium |
| **Linting** | RuboCop (omakase preset) |
| **Frontend** | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| **Assets** | Propshaft + Import Maps |
| **Deployment** | Kamal + Docker |
| **CI/CD** | GitHub Actions |
| **Jobs** | Solid Queue |
| **Cache** | Solid Cache |
| **Cable** | Solid Cable |

### Existing Security Tools

- Brakeman (Rails security scanner)
- Bundler-audit (gem vulnerabilities)
- Importmap audit (JS dependencies)

### Files to Protect

- `config/master.key` - Rails credentials encryption key
- `config/credentials.yml.enc` - Encrypted credentials
- `.kamal/secrets` - Deployment secrets
- `.env` - Local environment variables
- `storage/*.sqlite3` - Database files

---

## Phase 1: Global Configuration

### 1.1 Create Global Directory Structure

```bash
mkdir -p ~/.claude/{hooks,commands,agents,skills}
```

### 1.2 Create Global CLAUDE.md

**File:** `~/.claude/CLAUDE.md`

```markdown
# Global Claude Code Configuration

## Identity
- GitHub: [your-username]
- Primary Language: Ruby/Rails

## ABSOLUTE RULES - NEVER VIOLATE

### Secrets Protection
- NEVER output passwords, API keys, or tokens to any file
- NEVER read or output contents of:
  - .env, .env.*, config/master.key
  - config/credentials.yml.enc (encrypted, but don't expose)
  - .kamal/secrets
  - Any *.pem, *.key files
- NEVER commit secrets to git
- NEVER hardcode credentials in source files
- ALWAYS use Rails credentials or environment variables for secrets

### Dangerous Operations
- NEVER run rm -rf on root, home, or parent directories
- NEVER force push to main, master, or production branches
- NEVER use chmod 777
- NEVER run database commands without confirmation (db:drop, db:reset in production)

### Before Every Commit
1. Run bin/rubocop to check style
2. Run bin/rails test to verify tests pass
3. Run bin/brakeman to check security
4. Verify no .env or secret files are staged

## New Project Standards

### Required Files
- .env.example (template with placeholder values)
- .gitignore (must include .env, config/master.key)
- README.md
- CLAUDE.md (project-specific instructions)

### Rails Conventions
- Follow Rails conventions over configuration
- Use Rails credentials for secrets (bin/rails credentials:edit)
- Prefer Hotwire over heavy JavaScript frameworks
- Use Stimulus for JS interactivity
- Use Turbo for SPA-like navigation
- Write tests for all new functionality

## Quality Gates
- Max 100 lines per controller action
- Max 50 lines per model method
- Extract service objects for complex business logic
- Use concerns for shared model/controller behavior
```

### 1.3 Create Global settings.json

**File:** `~/.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "python3 ~/.claude/hooks/block-secrets.py"
        }]
      },
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/hooks/block-dangerous-commands.sh"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/hooks/rails-after-edit.sh"
        }]
      }
    ]
  },
  "permissions": {
    "deny": [
      "Read(.env)",
      "Read(.env.*)",
      "Read(config/master.key)",
      "Read(.kamal/secrets)",
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf ..)"
    ],
    "allow": [
      "Read(.env.example)",
      "Bash(git *)",
      "Bash(bin/rails *)",
      "Bash(bin/rubocop *)",
      "Bash(bin/brakeman *)",
      "Bash(bundle *)",
      "Bash(bin/dev)",
      "Bash(bin/setup)",
      "Bash(bin/ci)"
    ]
  }
}
```

---

## Phase 2: Project CLAUDE.md

### 2.1 Create Project CLAUDE.md

**File:** `./CLAUDE.md`

```markdown
# rails-claude Project Guide

## Overview
Modern Rails 8 application using the Solid trifecta (Cache, Queue, Cable) with SQLite, Hotwire frontend, and Kamal deployment.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Rails 8.2.0.alpha |
| Ruby | 3.3.6 |
| Database | SQLite 3 |
| Frontend | Hotwire (Turbo + Stimulus) |
| Styling | Tailwind CSS |
| Assets | Propshaft + Import Maps |
| Testing | Minitest + Capybara |
| Linting | RuboCop (omakase) |
| Deployment | Kamal + Docker |
| Jobs | Solid Queue |
| Cache | Solid Cache |
| WebSockets | Solid Cable |

## Project Structure

```
app/
├── controllers/     # Request handling
├── models/          # Business logic & data
├── views/           # ERB templates
├── helpers/         # View helpers
├── jobs/            # Background jobs (Solid Queue)
├── mailers/         # Email sending
├── channels/        # ActionCable channels
└── javascript/
    └── controllers/ # Stimulus controllers

config/
├── routes.rb        # URL routing
├── database.yml     # Database config (SQLite)
├── deploy.yml       # Kamal deployment
├── importmap.rb     # JavaScript imports
└── initializers/    # App initialization

test/
├── models/          # Unit tests
├── controllers/     # Controller tests
├── integration/     # Integration tests
├── system/          # Browser tests (Capybara)
└── fixtures/        # Test data
```

## Development Commands

```bash
# Setup
bin/setup              # Initialize development environment

# Development
bin/dev                # Start dev server (Rails + Tailwind watch)
bin/rails server       # Rails only
bin/rails console      # Rails console

# Testing
bin/rails test         # Run unit/integration tests
bin/rails test:system  # Run browser tests
bin/ci                 # Full CI suite locally

# Code Quality
bin/rubocop            # Check Ruby style
bin/rubocop -a         # Auto-fix style issues
bin/brakeman           # Security scan

# Database
bin/rails db:migrate   # Run migrations
bin/rails db:seed      # Seed data
bin/rails db:reset     # Reset database (CAREFUL!)

# Deployment
kamal setup            # Initial server setup
kamal deploy           # Deploy to production
kamal app logs         # View production logs
```

## Conventions

### Controllers
- Keep actions thin (< 10 lines ideally)
- Use before_action for auth/setup
- Respond with Turbo Streams for dynamic updates
- Use strong parameters

```ruby
# Good
def create
  @post = Post.new(post_params)
  if @post.save
    redirect_to @post, notice: "Created!"
  else
    render :new, status: :unprocessable_entity
  end
end

private

def post_params
  params.require(:post).permit(:title, :body)
end
```

### Models
- Validations at the top
- Associations after validations
- Scopes before methods
- Extract complex queries to scopes
- Use callbacks sparingly

```ruby
class Post < ApplicationRecord
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true

  # Associations
  belongs_to :user
  has_many :comments, dependent: :destroy

  # Scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def publish!
    update!(published: true, published_at: Time.current)
  end
end
```

### Views
- Use partials for reusable components
- Prefix partials with underscore (_partial.html.erb)
- Use Turbo Frames for partial page updates
- Use Turbo Streams for real-time updates

```erb
<%# Turbo Frame for in-place editing %>
<%= turbo_frame_tag @post do %>
  <h1><%= @post.title %></h1>
  <%= link_to "Edit", edit_post_path(@post) %>
<% end %>
```

### Stimulus Controllers
- One controller per behavior
- Use data attributes for configuration
- Keep controllers small and focused

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }
}
```

### Testing
- Test behavior, not implementation
- Use fixtures for test data
- System tests for critical user flows
- Run tests before committing

```ruby
# test/models/post_test.rb
class PostTest < ActiveSupport::TestCase
  test "requires title" do
    post = Post.new(body: "content")
    assert_not post.valid?
    assert_includes post.errors[:title], "can't be blank"
  end
end
```

## Security

### Credentials
- Use `bin/rails credentials:edit` to manage secrets
- Never commit config/master.key
- Use environment-specific credentials for staging/production

```ruby
# Access credentials
Rails.application.credentials.secret_api_key
Rails.application.credentials.dig(:aws, :access_key_id)
```

### Environment Variables
- Use .env for local development (never commit)
- Copy .env.example to .env and fill values
- Kamal uses .kamal/secrets for deployment

### Protected Files (NEVER read/output)
- .env, .env.*
- config/master.key
- config/credentials.yml.enc
- .kamal/secrets
- storage/*.sqlite3

## Deployment

### Kamal Commands
```bash
kamal setup            # First-time server setup
kamal deploy           # Deploy latest code
kamal rollback         # Rollback to previous version
kamal app logs         # View application logs
kamal app console      # Rails console on server
```

### Pre-deployment Checklist
1. All tests passing: `bin/rails test && bin/rails test:system`
2. No security issues: `bin/brakeman`
3. No vulnerable gems: `bundle audit`
4. Assets precompile: `bin/rails assets:precompile`

## Notes for Claude

### Do
- Follow existing patterns in the codebase
- Write tests for new functionality
- Use Rails conventions
- Keep methods small and focused
- Use Turbo/Stimulus for interactivity

### Don't
- Read or expose any files in "Protected Files" section
- Commit directly to main branch
- Skip tests
- Add unnecessary gems
- Over-engineer solutions
```

### 2.2 Create Project Local CLAUDE.md (Optional)

**File:** `./CLAUDE.local.md` (gitignored)

```markdown
# Local Development Overrides

## Personal Preferences
- Prefer verbose test output
- Always show SQL queries in console

## Local Environment
- Database: storage/development.sqlite3
- Server: http://localhost:3000
```

### 2.3 Update .gitignore

Add to `.gitignore`:

```gitignore
# Claude Code
CLAUDE.local.md
```

---

## Phase 3: Security Hooks

### 3.1 Block Secrets Hook

**File:** `~/.claude/hooks/block-secrets.py`

```python
#!/usr/bin/env python3
"""
PreToolUse hook to block access to sensitive Rails files.
Exit codes: 0 = allow, 1 = error, 2 = block
"""
import json
import sys
import re
from pathlib import Path

# Rails-specific sensitive files
SENSITIVE_FILES = {
    # Environment files
    '.env', '.env.local', '.env.development', '.env.test',
    '.env.production', '.env.staging',
    # Rails credentials
    'master.key', 'credentials.yml.enc',
    'development.key', 'test.key', 'production.key',
    # Kamal secrets
    'secrets',
    # SSH keys
    'id_rsa', 'id_ed25519', 'id_ecdsa',
    # Generic secrets
    'secrets.json', 'secrets.yaml', 'secrets.yml',
    # Database files (prevent accidental exposure)
    'development.sqlite3', 'test.sqlite3', 'production.sqlite3',
}

SENSITIVE_EXTENSIONS = {
    '.pem', '.key', '.p12', '.pfx', '.jks', '.keystore'
}

SENSITIVE_PATTERNS = [
    r'\.env(\.|$)',           # .env files
    r'master\.key$',          # Rails master key
    r'credentials.*\.enc$',   # Encrypted credentials
    r'\.kamal/secrets$',      # Kamal secrets
    r'secret', r'credential', r'private_key', r'api_key',
]

SENSITIVE_PATHS = [
    'config/master.key',
    'config/credentials.yml.enc',
    '.kamal/secrets',
]

def is_sensitive(file_path: str) -> tuple[bool, str]:
    """Check if file is sensitive. Returns (is_sensitive, reason)."""
    path = Path(file_path)
    path_str = str(path)

    # Check exact path matches
    for sensitive_path in SENSITIVE_PATHS:
        if path_str.endswith(sensitive_path):
            return True, f"Protected Rails file: {sensitive_path}"

    # Check exact filename matches
    if path.name in SENSITIVE_FILES:
        return True, f"Sensitive filename: {path.name}"

    # Check extensions
    if path.suffix.lower() in SENSITIVE_EXTENSIONS:
        return True, f"Sensitive file type: {path.suffix}"

    # Check patterns
    path_lower = file_path.lower()
    for pattern in SENSITIVE_PATTERNS:
        if re.search(pattern, path_lower):
            return True, f"Matches sensitive pattern: {pattern}"

    return False, ""

def main():
    try:
        data = json.load(sys.stdin)
        tool_input = data.get('tool_input', {})

        # Check file_path for Read/Edit/Write tools
        file_path = tool_input.get('file_path', '')

        if file_path:
            sensitive, reason = is_sensitive(file_path)
            if sensitive:
                print(f"BLOCKED: {reason}", file=sys.stderr)
                print(f"File: {file_path}", file=sys.stderr)
                print("", file=sys.stderr)
                print("For secrets, use:", file=sys.stderr)
                print("  - bin/rails credentials:edit", file=sys.stderr)
                print("  - Environment variables via .env.example", file=sys.stderr)
                sys.exit(2)

        sys.exit(0)

    except json.JSONDecodeError:
        print("Hook error: Invalid JSON input", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
```

Make executable:
```bash
chmod +x ~/.claude/hooks/block-secrets.py
```

### 3.2 Block Dangerous Commands Hook

**File:** `~/.claude/hooks/block-dangerous-commands.sh`

```bash
#!/bin/bash
#
# PreToolUse hook to block dangerous bash commands.
# Exit codes: 0 = allow, 1 = error, 2 = block
#

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))" 2>/dev/null)

if [ -z "$COMMAND" ]; then
    exit 0
fi

# Block destructive rm commands
if echo "$COMMAND" | grep -qE 'rm\s+(-rf|-fr|-r\s+-f|-f\s+-r)\s+(/|~|\.\.|/\*|~/\*)'; then
    echo "BLOCKED: Destructive rm command" >&2
    echo "Command: $COMMAND" >&2
    exit 2
fi

# Block force push to protected branches
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force.*\s*(main|master|production|staging)'; then
    echo "BLOCKED: Force push to protected branch" >&2
    echo "Use a feature branch and create a PR instead." >&2
    exit 2
fi

# Block chmod 777
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
    echo "BLOCKED: chmod 777 makes files world-writable" >&2
    echo "Use restrictive permissions: 755 for dirs, 644 for files." >&2
    exit 2
fi

# Block piping curl/wget to shell
if echo "$COMMAND" | grep -qE '(curl|wget).*\|\s*(bash|sh|zsh|ruby)'; then
    echo "BLOCKED: Piping remote content to shell" >&2
    echo "Download first, review, then execute." >&2
    exit 2
fi

# Block dangerous database commands without confirmation context
if echo "$COMMAND" | grep -qE 'rails\s+(db:drop|db:reset).*production'; then
    echo "BLOCKED: Destructive database command in production" >&2
    exit 2
fi

# Block reading .env files via cat/less/more
if echo "$COMMAND" | grep -qE '(cat|less|more|head|tail|vim|nano)\s+.*\.env'; then
    echo "BLOCKED: Reading .env file via shell" >&2
    echo "Use .env.example for templates." >&2
    exit 2
fi

# Block exposing master.key
if echo "$COMMAND" | grep -qE '(cat|less|more|head|tail)\s+.*master\.key'; then
    echo "BLOCKED: Exposing Rails master key" >&2
    exit 2
fi

# Allow command
exit 0
```

Make executable:
```bash
chmod +x ~/.claude/hooks/block-dangerous-commands.sh
```

### 3.3 Rails After-Edit Hook (Optional)

**File:** `~/.claude/hooks/rails-after-edit.sh`

```bash
#!/bin/bash
#
# PostToolUse hook to run after file edits.
# Runs RuboCop on edited Ruby files.
#

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tool_input', {}).get('file_path', ''))" 2>/dev/null)

# Only check Ruby files
if [[ "$FILE_PATH" == *.rb ]]; then
    if command -v rubocop &> /dev/null; then
        rubocop "$FILE_PATH" --format simple 2>/dev/null || true
    fi
fi

exit 0
```

Make executable:
```bash
chmod +x ~/.claude/hooks/rails-after-edit.sh
```

---

## Phase 4: Custom Commands

### 4.1 Rails Test Command

**File:** `~/.claude/commands/rails-test.md`

```markdown
---
description: Run Rails tests with options
argument-hint: [test file or pattern]
allowed-tools: Bash(bin/rails test:*), Bash(bin/rails test)
---

## Context
- Current branch: !`git branch --show-current`
- Modified files: !`git diff --name-only HEAD`

## Task
Run Rails tests. If arguments provided, run specific tests:
- `$ARGUMENTS`

If no arguments, run the full test suite.

Use:
- `bin/rails test` for unit/integration tests
- `bin/rails test:system` for browser tests
- `bin/rails test path/to/test.rb` for specific file
- `bin/rails test path/to/test.rb:42` for specific line
```

### 4.2 Rails Lint Command

**File:** `~/.claude/commands/lint.md`

```markdown
---
description: Run RuboCop linter
argument-hint: [--fix or file path]
allowed-tools: Bash(bin/rubocop:*)
---

## Task
Run RuboCop on the codebase.

Arguments: $ARGUMENTS

- No args: `bin/rubocop` (check all)
- `--fix` or `-a`: `bin/rubocop -a` (auto-fix)
- File path: `bin/rubocop path/to/file.rb`
```

### 4.3 Rails Security Command

**File:** `~/.claude/commands/security.md`

```markdown
---
description: Run security scans (Brakeman + bundle audit)
allowed-tools: Bash(bin/brakeman:*), Bash(bundle audit:*)
---

## Context
- Last security scan: Check for existing reports

## Task
Run full security audit:

1. **Brakeman** - Rails security scanner
   ```bash
   bin/brakeman --no-pager
   ```

2. **Bundle Audit** - Gem vulnerabilities
   ```bash
   bundle audit check --update
   ```

3. **Import Map Audit** - JS dependencies
   ```bash
   bin/importmap audit
   ```

Report findings with severity levels and remediation steps.
```

### 4.4 Rails Generate Command

**File:** `~/.claude/commands/generate.md`

```markdown
---
description: Generate Rails components with best practices
argument-hint: <type> <name> [attributes...]
allowed-tools: Bash(bin/rails generate:*), Bash(bin/rails g:*)
---

## Task
Generate Rails component: $ARGUMENTS

Common generators:
- `model Post title:string body:text user:references`
- `controller Posts index show new create edit update destroy`
- `migration AddStatusToPosts status:integer:index`
- `scaffold Post title:string body:text` (full CRUD)
- `stimulus toggle` (Stimulus controller)
- `channel notifications` (ActionCable channel)

After generation:
1. Review generated files
2. Run `bin/rails db:migrate` if migration created
3. Add tests for new functionality
```

### 4.5 CI Command

**File:** `~/.claude/commands/ci.md`

```markdown
---
description: Run full CI suite locally
allowed-tools: Bash(bin/ci:*), Bash(bin/rails:*), Bash(bin/rubocop:*), Bash(bin/brakeman:*)
---

## Context
- Current branch: !`git branch --show-current`
- Uncommitted changes: !`git status --short`

## Task
Run the full CI suite locally using `bin/ci`.

This runs:
1. Setup (bundle, db:prepare)
2. RuboCop (style)
3. Bundler-audit (gem security)
4. Import map audit (JS security)
5. Brakeman (Rails security)
6. Tests (bin/rails test)
7. Seed validation

Report any failures with details.
```

---

## Phase 5: Skills

### 5.1 Rails Model Skill

**File:** `.claude/skills/rails-model/SKILL.md`

```markdown
---
name: Rails Model
description: Create well-structured Rails models with validations, associations, and tests
triggers:
  - create model
  - add model
  - model for
---

# Rails Model Creation

## Model Structure Pattern

```ruby
class ModelName < ApplicationRecord
  # Constants
  STATUSES = %w[draft published archived].freeze

  # Enums
  enum :status, { draft: 0, published: 1, archived: 2 }

  # Validations (alphabetical)
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: STATUSES }

  # Associations (alphabetical)
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_one :profile, dependent: :destroy

  # Scopes (alphabetical)
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :published, -> { where(status: :published) }

  # Callbacks (use sparingly)
  before_validation :normalize_email, on: :create
  after_create_commit :notify_admin

  # Class methods
  def self.search(query)
    where("name ILIKE ?", "%#{query}%")
  end

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def notify_admin
    AdminMailer.new_record(self).deliver_later
  end
end
```

## Test Pattern

```ruby
# test/models/model_name_test.rb
require "test_helper"

class ModelNameTest < ActiveSupport::TestCase
  # Validations
  test "requires name" do
    record = ModelName.new(name: nil)
    assert_not record.valid?
    assert_includes record.errors[:name], "can't be blank"
  end

  test "requires unique email" do
    existing = model_names(:one)
    record = ModelName.new(email: existing.email)
    assert_not record.valid?
    assert_includes record.errors[:email], "has already been taken"
  end

  # Scopes
  test ".published returns only published records" do
    published = model_names(:published)
    draft = model_names(:draft)

    results = ModelName.published

    assert_includes results, published
    assert_not_includes results, draft
  end

  # Methods
  test "#full_name combines first and last name" do
    record = ModelName.new(first_name: "John", last_name: "Doe")
    assert_equal "John Doe", record.full_name
  end
end
```

## Checklist
- [ ] Migration with proper column types and indexes
- [ ] Validations for required fields
- [ ] Associations with dependent options
- [ ] Scopes for common queries
- [ ] Tests for validations and methods
- [ ] Fixtures for test data
```

### 5.2 Rails Controller Skill

**File:** `.claude/skills/rails-controller/SKILL.md`

```markdown
---
name: Rails Controller
description: Create RESTful Rails controllers with Turbo support
triggers:
  - create controller
  - add controller
  - controller for
---

# Rails Controller Creation

## Controller Pattern

```ruby
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: %i[show edit update destroy]
  before_action :authorize_post, only: %i[edit update destroy]

  def index
    @posts = Post.published.recent.page(params[:page])
  end

  def show
  end

  def new
    @post = current_user.posts.build
  end

  def create
    @post = current_user.posts.build(post_params)

    if @post.save
      redirect_to @post, notice: "Post created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: "Post deleted.", status: :see_other
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def authorize_post
    redirect_to posts_path, alert: "Not authorized." unless @post.user == current_user
  end

  def post_params
    params.require(:post).permit(:title, :body, :published)
  end
end
```

## With Turbo Streams

```ruby
def create
  @post = current_user.posts.build(post_params)

  respond_to do |format|
    if @post.save
      format.turbo_stream
      format.html { redirect_to @post, notice: "Created!" }
    else
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

```erb
<%# app/views/posts/create.turbo_stream.erb %>
<%= turbo_stream.prepend "posts", @post %>
<%= turbo_stream.update "new_post_form", partial: "posts/form", locals: { post: Post.new } %>
```

## Controller Test Pattern

```ruby
# test/controllers/posts_controller_test.rb
require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @post = posts(:one)
  end

  test "should get index" do
    get posts_url
    assert_response :success
  end

  test "should create post when logged in" do
    sign_in @user

    assert_difference("Post.count") do
      post posts_url, params: { post: { title: "New", body: "Content" } }
    end

    assert_redirected_to post_url(Post.last)
  end

  test "should not create post when logged out" do
    post posts_url, params: { post: { title: "New", body: "Content" } }
    assert_redirected_to new_session_url
  end
end
```
```

### 5.3 Stimulus Controller Skill

**File:** `.claude/skills/stimulus/SKILL.md`

```markdown
---
name: Stimulus Controller
description: Create Stimulus controllers for JavaScript interactivity
triggers:
  - stimulus
  - js controller
  - javascript controller
  - interactivity
---

# Stimulus Controller Creation

## Basic Pattern

```javascript
// app/javascript/controllers/example_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Define elements to reference
  static targets = ["input", "output"]

  // Define CSS classes to toggle
  static classes = ["active", "hidden"]

  // Define configurable values
  static values = {
    url: String,
    refreshInterval: { type: Number, default: 5000 }
  }

  // Lifecycle: when controller connects to DOM
  connect() {
    console.log("Controller connected")
  }

  // Lifecycle: when controller disconnects
  disconnect() {
    console.log("Controller disconnected")
  }

  // Action methods (called from data-action)
  submit(event) {
    event.preventDefault()
    this.outputTarget.textContent = this.inputTarget.value
  }

  toggle() {
    this.element.classList.toggle(this.activeClass)
  }

  // Value change callbacks
  urlValueChanged() {
    this.load()
  }
}
```

## HTML Usage

```erb
<div data-controller="example"
     data-example-url-value="<%= api_path %>"
     data-example-active-class="bg-blue-500">

  <input data-example-target="input"
         data-action="input->example#submit">

  <button data-action="click->example#toggle">
    Toggle
  </button>

  <div data-example-target="output"></div>
</div>
```

## Common Patterns

### Debounce
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { delay: { type: Number, default: 300 } }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.performSearch()
    }, this.delayValue)
  }

  performSearch() {
    // Actual search logic
  }
}
```

### Fetch Data
```javascript
async load() {
  const response = await fetch(this.urlValue)
  const html = await response.text()
  this.outputTarget.innerHTML = html
}
```

### Toggle Visibility
```javascript
static targets = ["content"]

toggle() {
  this.contentTarget.classList.toggle("hidden")
}

show() {
  this.contentTarget.classList.remove("hidden")
}

hide() {
  this.contentTarget.classList.add("hidden")
}
```

## Generate Command
```bash
bin/rails generate stimulus controller_name
```
```

---

## Phase 6: Custom Agents

### 6.1 Rails Reviewer Agent

**File:** `~/.claude/agents/rails-reviewer.md`

```markdown
---
name: rails-reviewer
description: Reviews Rails code for security, performance, and Rails conventions
tools: Read, Grep, Glob
model: sonnet
---

You are a senior Rails developer reviewing code. Focus on:

## Security (Critical)
- SQL injection (use parameterized queries)
- XSS (escape output, use safe methods)
- CSRF protection (verify_authenticity_token)
- Mass assignment (strong parameters)
- Authentication/authorization checks
- Secrets exposure (no hardcoded credentials)

## Performance
- N+1 queries (use includes/preload)
- Missing database indexes
- Inefficient queries
- Memory bloat (large collections)
- Unnecessary callbacks

## Rails Conventions
- RESTful routes and actions
- Thin controllers, fat models (but not too fat)
- Service objects for complex logic
- Concerns for shared behavior
- Proper use of validations
- Test coverage

## Code Quality
- Method length (< 15 lines ideal)
- Class length (< 200 lines)
- Single responsibility
- Clear naming
- DRY without over-abstraction

Provide specific file:line references and concrete fix suggestions.
```

### 6.2 Rails Test Writer Agent

**File:** `~/.claude/agents/rails-test-writer.md`

```markdown
---
name: rails-test-writer
description: Writes comprehensive Rails tests (Minitest)
tools: Read, Write, Edit, Glob, Grep
model: sonnet
---

You are a test-driven development expert for Rails using Minitest.

## Test Types

### Model Tests
- Validations (presence, uniqueness, format)
- Associations (belongs_to, has_many)
- Scopes (return correct records)
- Instance methods (correct output)
- Class methods (correct behavior)

### Controller Tests
- HTTP responses (status codes)
- Authentication requirements
- Authorization (who can access what)
- Redirects and flash messages
- Strong parameters

### System Tests (Capybara)
- Critical user flows
- Form submissions
- JavaScript interactions
- Error handling

## Test Structure
```ruby
require "test_helper"

class ModelTest < ActiveSupport::TestCase
  setup do
    @record = records(:one)
  end

  # Group related tests
  test "validates presence of name" do
    @record.name = nil
    assert_not @record.valid?
    assert_includes @record.errors[:name], "can't be blank"
  end
end
```

## Best Practices
- Test behavior, not implementation
- Use fixtures for test data
- One assertion concept per test
- Descriptive test names
- Setup common objects in setup block
- Use assert_difference for counts
```

### 6.3 Rails Migration Agent

**File:** `~/.claude/agents/rails-migration.md`

```markdown
---
name: rails-migration
description: Creates safe, reversible Rails database migrations
tools: Read, Write, Bash, Glob
model: sonnet
---

You are a database migration expert for Rails.

## Migration Best Practices

### Always
- Make migrations reversible when possible
- Add indexes for foreign keys
- Add indexes for columns used in WHERE/ORDER
- Use `null: false` with defaults for new columns
- Consider data migration separately from schema

### Column Additions
```ruby
# Safe: add with default, then remove default
add_column :posts, :status, :integer, default: 0, null: false
```

### Removing Columns (2-step)
```ruby
# Step 1: Ignore in model
# Step 2: Remove after deploy
remove_column :posts, :legacy_field
```

### Adding Indexes
```ruby
# For large tables, use CONCURRENTLY (PostgreSQL)
add_index :posts, :user_id, algorithm: :concurrently

# For SQLite, standard index
add_index :posts, :user_id
```

### Foreign Keys
```ruby
add_reference :posts, :user, null: false, foreign_key: true
```

## Generate Command
```bash
bin/rails generate migration AddStatusToPosts status:integer:index
```

## After Creating
1. Review the migration file
2. Run `bin/rails db:migrate`
3. Check `db/schema.rb` for expected changes
4. Run tests to verify no regressions
```

---

## Phase 7: MCP Servers

### 7.1 Recommended MCP Servers for Rails

```bash
# GitHub integration (PRs, issues)
claude mcp add github -- npx -y @modelcontextprotocol/server-github

# PostgreSQL (if switching from SQLite)
claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres

# Sequential thinking for complex problems
claude mcp add thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# Context7 for live documentation
claude mcp add context7 -- npx -y context7-mcp
```

### 7.2 MCP Configuration

**File:** `~/.claude/settings.json` (add to existing)

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
```

---

## Implementation Checklist

### Phase 1: Global Configuration
- [ ] Create `~/.claude/` directory structure
- [ ] Create `~/.claude/CLAUDE.md` with global rules
- [ ] Create `~/.claude/settings.json` with hooks config

### Phase 2: Project CLAUDE.md
- [ ] Create `./CLAUDE.md` with project documentation
- [ ] Create `./CLAUDE.local.md` for personal overrides (optional)
- [ ] Add `CLAUDE.local.md` to `.gitignore`

### Phase 3: Security Hooks
- [ ] Create `~/.claude/hooks/block-secrets.py`
- [ ] Create `~/.claude/hooks/block-dangerous-commands.sh`
- [ ] Create `~/.claude/hooks/rails-after-edit.sh` (optional)
- [ ] Make all hooks executable (`chmod +x`)
- [ ] Test hooks work correctly

### Phase 4: Custom Commands
- [ ] Create `~/.claude/commands/rails-test.md`
- [ ] Create `~/.claude/commands/lint.md`
- [ ] Create `~/.claude/commands/security.md`
- [ ] Create `~/.claude/commands/generate.md`
- [ ] Create `~/.claude/commands/ci.md`

### Phase 5: Skills
- [ ] Create `.claude/skills/rails-model/SKILL.md`
- [ ] Create `.claude/skills/rails-controller/SKILL.md`
- [ ] Create `.claude/skills/stimulus/SKILL.md`

### Phase 6: Custom Agents
- [ ] Create `~/.claude/agents/rails-reviewer.md`
- [ ] Create `~/.claude/agents/rails-test-writer.md`
- [ ] Create `~/.claude/agents/rails-migration.md`

### Phase 7: MCP Servers
- [ ] Install GitHub MCP server
- [ ] Install Sequential Thinking MCP server
- [ ] Configure MCP in settings.json

### Verification
- [ ] Run `/doctor` to check configuration
- [ ] Test a command (e.g., `/ci`)
- [ ] Verify hooks block sensitive file access
- [ ] Test agent delegation works

---

## Quick Start Commands

After setup, use these commands in Claude Code:

```bash
/ci              # Run full CI suite
/lint            # Check code style
/lint --fix      # Auto-fix style issues
/security        # Run security scans
/rails-test      # Run tests
/generate        # Generate Rails components
```

---

*Plan created for rails-claude project based on Claude Code V4 guide.*
