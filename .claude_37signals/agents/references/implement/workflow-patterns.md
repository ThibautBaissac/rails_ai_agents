# Implementation Workflow Patterns

## Pattern 1: New CRUD Resource

**Scenario:** Add a new resource (e.g., Projects) to the application.

```
1. Migration:   Create table with account_id, UUIDs, proper indexes
2. Model:       Create model with validations, associations, scopes, concerns
3. Controller:  Create controller with CRUD actions scoped to Current.account
4. Views:       Add Turbo Frames/Streams for real-time updates
5. Tests:       Model, controller, and system tests with fixtures
6. Caching:     HTTP caching with fresh_when/ETags
7. API:         JSON responses via respond_to + Jbuilder
```

**Example prompts per step:**
- Migration: "Create a projects table with account_id, name, description, status, creator_id, and indexes for multi-tenant app with UUIDs"
- Model: "Create Project model belonging to account and creator, has many tasks, includes Closeable concern"
- Controller: "Create ProjectsController with full CRUD scoped to Current.account"
- Turbo: "Add Turbo Stream broadcasts to Project for real-time create/update/destroy"
- Tests: "Create tests for Project model and ProjectsController including account scoping"

## Pattern 2: State Management Feature

**Scenario:** Track when projects are archived (not a boolean -- a record).

```
1. State records:  Implement Archival pattern (has_one :archival)
2. Migration:      Create archivals table with project_id, user_id, account_id
3. Model:          Add has_one :archival to Project, add Archivable concern
4. Controller:     Create Projects::ArchivalsController (create/destroy)
5. Events:         Create ProjectArchived event for activity tracking
6. Tests:          Test archival creation, project.archived? queries
```

## Pattern 3: Real-Time Collaboration

**Scenario:** Live updates when team members edit projects.

```
1. Turbo:      Set up Turbo Stream broadcasting for project updates
2. Stimulus:   Add JavaScript for presence indicators
3. Events:     Track edit events (ProjectEdited)
4. Caching:    Configure cache invalidation with touch: true
5. Tests:      System tests for real-time behavior
```

## Pattern 4: Notification System

**Scenario:** Email notifications for project mentions.

```
1. Model:      Add mention detection to Comment model
2. Mailer:     Create MentionMailer with bundled notifications
3. Jobs:       Create digest job for batched emails
4. Migration:  Add notification_preferences table
5. Controller: Create NotificationPreferencesController (CRUD)
6. Tests:      Test mention detection and email delivery
```

## Pattern 5: Complete Multi-Tenant Setup

**Scenario:** Add multi-tenancy to an existing application.

```
1. Multi-tenant: Create Account model, Membership, Current attributes
2. Migration:    Add account_id to all existing tables with backfills
3. Model:        Add belongs_to :account to all models
4. Controller:   Update all controllers for Current.account scoping
5. Auth:         Update authentication for account context
6. Tests:        Update all tests for multi-tenant isolation
7. API:          Add account scoping to JSON endpoints
```

## Pattern 6: Background Processing Feature

**Scenario:** Export large datasets as CSV.

```
1. Jobs:       Create ExportJob with Solid Queue
2. Model:      Add export_later method to exportable models
3. Controller: Create ExportsController as CRUD resource
4. Mailer:     Email notification when export completes
5. Turbo:      Real-time progress updates via Turbo Stream
6. Tests:      Job tests with fixtures
```

## Pattern 7: API Endpoint

**Scenario:** Expose projects via REST API.

```
1. API:        Add respond_to :json to ProjectsController
2. Views:      Create Jbuilder templates (index.json.jbuilder, show.json.jbuilder)
3. Auth:       Create API token authentication
4. Caching:    Add ETag caching for API responses
5. Tests:      API integration tests with JSON assertions
```

## Pattern 8: Activity Feed

**Scenario:** Show recent project activity.

```
1. Events:     Create domain events (ProjectCreated, ProjectUpdated, etc.)
2. Migration:  Create activities table (polymorphic trackable)
3. Model:      Add has_many :activities to Project
4. Controller: Create ActivitiesController (index/show only)
5. Turbo:      Real-time activity feed updates via broadcast
6. Caching:    Fragment caching for activity feed items
7. Tests:      Activity creation and display tests
```

## Pattern 9: Search Feature

**Scenario:** Search projects and tasks.

```
1. Controller: Create SearchesController (search is a CRUD resource)
2. Model:      Add search scopes to Project and Task models
3. Concerns:   Extract Searchable concern for shared search behavior
4. Stimulus:   Live search with debouncing
5. Caching:    Cache search results with proper invalidation
6. Tests:      Search integration tests
```

## Pattern 10: Approval Workflow

**Scenario:** Project approval process.

```
1. State records: Implement Publication pattern for approvals
2. Migration:     Create publications table
3. Model:         Add approval business logic to Project model
4. Controller:    Create Projects::PublicationsController (create/destroy)
5. Mailer:        Approval request and confirmation emails
6. Events:        Track approval events for audit trail
7. Tests:         Workflow integration tests with fixtures
```
