# Migration Strategies

## RSpec to Minitest

### Syntax Conversion

```ruby
# RSpec
RSpec.describe Project do
  let(:user) { create(:user) }
  let(:project) { create(:project, creator: user) }

  describe "#archive" do
    it "sets archived_at" do
      project.archive
      expect(project.archived_at).to be_present
    end

    it "sends notification" do
      expect { project.archive }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context "when already archived" do
    before { project.archive }

    it "raises error" do
      expect { project.archive }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

# Minitest equivalent
class ProjectTest < ActiveSupport::TestCase
  test "archive creates archival record" do
    project = projects(:active_project)
    project.archive
    assert project.archived?
  end

  test "archive sends notification" do
    project = projects(:active_project)
    assert_emails 1 do
      project.archive
    end
  end

  test "archive raises when already archived" do
    project = projects(:archived_project)
    assert_raises(ActiveRecord::RecordInvalid) do
      project.archive
    end
  end
end
```

### Key Conversions

| RSpec | Minitest |
|-------|---------|
| `describe / context` | Flat `test` blocks (no nesting) |
| `let(:x) { create(:x) }` | `x = xs(:fixture_name)` |
| `before { ... }` | Inline setup or use fixture with state |
| `expect(x).to eq(y)` | `assert_equal y, x` |
| `expect(x).to be_present` | `assert x.present?` |
| `expect(x).to be_nil` | `assert_nil x` |
| `expect(x).to be true` | `assert x` |
| `expect { }.to change { }.by(n)` | `assert_difference -> { }, n do ... end` |
| `expect { }.to raise_error(E)` | `assert_raises(E) { }` |
| `expect(x).to include(y)` | `assert_includes x, y` |
| `shared_examples` | Concern tests or modules |

### FactoryBot to Fixtures

```ruby
# FactoryBot factory
FactoryBot.define do
  factory :project do
    account
    sequence(:name) { |n| "Project #{n}" }
    creator { association(:user) }
    status { :active }

    trait :archived do
      archived_at { Time.current }
    end
  end
end

# Equivalent fixtures (test/fixtures/projects.yml)
active_project:
  account: fizzy
  name: "Q4 Planning"
  creator: alice (User)

archived_project:
  account: fizzy
  name: "Old Project"
  creator: alice (User)

other_account_project:
  account: other_company
  name: "Their Project"
  creator: bob (User)
```

### Migration Steps
1. Create fixture files from factory definitions (one model at a time)
2. Convert one test file: replace `create(:x)` with `xs(:fixture_name)`
3. Run both suites in parallel to verify equivalence
4. Repeat for all test files
5. Remove RSpec and FactoryBot gems after 100% conversion

## Sidekiq to Solid Queue

### Before (Sidekiq)
```ruby
# Gemfile
gem "sidekiq"
gem "redis"

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end

# app/workers/export_worker.rb
class ExportWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(report_id)
    report = Report.find(report_id)
    report.generate_data!
    ReportMailer.completed(report).deliver_now
  end
end

# Usage
ExportWorker.perform_async(report.id)
```

### After (Solid Queue)
```ruby
# Gemfile
gem "solid_queue"

# config/queue.yml - no Redis needed
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 0.1

# app/jobs/export_job.rb
class ExportJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(report)
    report.generate_data!
  end
end

# app/models/report.rb
class Report < ApplicationRecord
  def generate_later
    ExportJob.perform_later(self)
  end

  def generate_now
    ExportJob.perform_now(self)
  end

  after_update_commit :notify_completion, if: :completed?

  private
    def notify_completion
      ReportMailer.completed(self).deliver_later
    end
end

# Usage
report.generate_later
```

### Key Differences

| Sidekiq | Solid Queue |
|---------|-------------|
| `include Sidekiq::Worker` | `< ApplicationJob` |
| `perform_async(id)` | `perform_later(record)` |
| Passes IDs, finds record | Passes ActiveRecord objects directly |
| `sidekiq_options` | `queue_as`, `retry_on` |
| Redis required | Database-backed (no Redis) |
| Worker classes | Job classes |
| Logic in worker | Logic in model, job just calls it |

### Migration Steps
1. Install Solid Queue alongside Sidekiq
2. Create ApplicationJob subclasses for each Sidekiq worker
3. Move worker logic to model methods
4. Make jobs shallow (call model method only)
5. Add `_later` / `_now` methods to models
6. Route new jobs to Solid Queue, old ones stay on Sidekiq
7. Migrate remaining jobs one at a time
8. Remove Sidekiq and Redis after all jobs migrated

## React/Vue to Turbo + Stimulus

### Before (React SPA)
```javascript
// React component
function ProjectList({ projects }) {
  const [filter, setFilter] = useState('all');

  return (
    <div>
      <select onChange={(e) => setFilter(e.target.value)}>
        <option value="all">All</option>
        <option value="active">Active</option>
      </select>
      {projects.filter(p => filter === 'all' || p.status === filter)
        .map(p => <ProjectCard key={p.id} project={p} />)}
    </div>
  );
}
```

### After (ERB + Turbo + Stimulus)
```erb
<%# app/views/projects/index.html.erb %>
<%= turbo_frame_tag "projects" do %>
  <div data-controller="filter">
    <select data-action="change->filter#update"
            data-filter-url-value="<%= projects_path %>">
      <option value="all">All</option>
      <option value="active">Active</option>
    </select>

    <div id="project_list">
      <%= render @projects %>
    </div>
  </div>
<% end %>
```

```javascript
// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  update(event) {
    const url = new URL(this.urlValue)
    url.searchParams.set("status", event.target.value)
    Turbo.visit(url, { frame: "projects" })
  }
}
```

### Migration Steps
1. Add HTML responses to API controllers (respond_to block)
2. Create ERB views equivalent to React components (one page at a time)
3. Replace React state management with Turbo Frames
4. Replace event handlers with Stimulus controllers
5. Use feature flag to serve React vs. Turbo version per route
6. Test both versions, migrate route by route
7. Remove React, Webpack, Node.js after full migration

## Redis to Solid Cache / Solid Cable

### Caching: Redis to Solid Cache
```ruby
# Before
# config/environments/production.rb
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }

# After
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

### WebSockets: Redis to Solid Cable
```ruby
# Before
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV["REDIS_URL"] %>

# After
# config/cable.yml
production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
```

### Migration Steps
1. Install Solid Cache, configure alongside Redis
2. Monitor cache hit rates, compare Redis vs. Solid Cache
3. Switch primary cache store to Solid Cache
4. Install Solid Cable, test WebSocket connections
5. Switch cable adapter to Solid Cable
6. Remove Redis from infrastructure after verification
