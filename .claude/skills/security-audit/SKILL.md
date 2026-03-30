---
name: security-audit
description: >-
  Audits Rails application security against OWASP Top 10, detects
  vulnerabilities with Brakeman, and verifies Pundit authorization policies.
  Use when the user wants a security audit, vulnerability scan, or when user
  mentions security, OWASP, Brakeman, XSS, SQL injection, or authorization.
  WHEN NOT: Implementing security fixes (use specialist agents), setting up
  authentication (use authentication-flow), or writing Pundit policies (use
  policy-agent).
context: fork
agent: Explore
model: opus
effort: high
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
argument-hint: "[file or directory path]"
---

# Security Audit

You are an expert in Rails application security, OWASP Top 10, and common web vulnerabilities.
You NEVER modify credentials, secrets, or production files.

## Audit Process

### Step 1: Run Security Tools

```bash
bin/brakeman
bin/bundler-audit check --update
bundle exec rspec spec/policies/
```

### Step 2: Manual Code Review

Audit all files in `app/controllers/`, `app/models/`, `app/services/`,
`app/queries/`, `app/forms/`, `app/views/`, `app/policies/`, `config/`.

### Step 3: Report Findings

Format: **Vulnerability** → **Location** (file:line) → **Risk** → **Fix** (code example)
Prioritize: P0 (critical) → P1 (high) → P2 (medium) → P3 (low)

## OWASP Top 10 — Rails Patterns

### 1. Injection (SQL, Command)
```ruby
# Bad — SQL Injection
User.where("email = '#{params[:email]}'")

# Good — Bound parameters
User.where(email: params[:email])
```

### 2. Broken Authentication
```ruby
# Bad — Predictable token
user.update(reset_token: SecureRandom.hex(4))

# Good — Sufficiently long token
user.update(reset_token: SecureRandom.urlsafe_base64(32))
```

### 3. Sensitive Data Exposure
```ruby
# Bad — Logging sensitive data
Rails.logger.info("Password: #{password}")

# Good — Filter sensitive params
Rails.application.config.filter_parameters += [:password, :token, :secret]
```

### 4. XXE
```ruby
# Bad
Nokogiri::XML(user_input)

# Good
Nokogiri::XML(user_input) { |config| config.nonet.noent }
```

### 5. Broken Access Control
```ruby
# Bad — No authorization
@entity = Entity.find(params[:id])

# Good — Pundit
@entity = Entity.find(params[:id])
authorize @entity
```

### 6. Security Misconfiguration
```ruby
# production.rb
config.force_ssl = true
```

### 7. XSS
```erb
<%# Bad %>
<%= raw user_input %>
<%= user_input.html_safe %>

<%# Good %>
<%= user_input %>
<%= sanitize(user_input) %>
```

### 8. Insecure Deserialization
```ruby
# Bad
YAML.load(user_input)

# Good
YAML.safe_load(user_input, permitted_classes: [Symbol, Date])
```

### 9. Vulnerable Dependencies
```bash
bin/bundler-audit check --update
```

### 10. Insufficient Logging
```ruby
Rails.logger.warn("Failed login for #{email} from #{request.remote_ip}")
```

## Security Checklist

### Configuration
- [ ] `config.force_ssl = true` in production
- [ ] CSRF protection enabled
- [ ] Content Security Policy configured
- [ ] Sensitive parameters filtered from logs
- [ ] Secure sessions (httponly, secure, same_site)

### Code
- [ ] Strong Parameters on all controllers
- [ ] Pundit `authorize` on all actions
- [ ] No `html_safe`/`raw` on user input
- [ ] Parameterized SQL queries only
- [ ] File upload validation

### Dependencies
- [ ] Bundler Audit clean
- [ ] Gems up to date
- [ ] No abandoned gems
