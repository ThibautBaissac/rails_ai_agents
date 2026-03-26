# Webhooks Reference

## Webhook System Architecture

```
Event created (via track_event)
  -> Event after_create_commit :dispatch_webhooks
    -> Event::WebhookDispatchJob.perform_later(event)
      -> Webhook.active.triggered_by(event)  (scoped to board + subscribed actions)
        -> webhook.trigger(event)
          -> Webhook::Delivery.create!(webhook:, event:)
            -> Delivery after_create_commit :deliver_later
              -> Webhook::DeliveryJob.perform_later(delivery)
                -> delivery.deliver (HTTP POST with HMAC signature)
                  -> webhook.delinquency_tracker.record_delivery_of(delivery)
```

## Webhook Model

Webhooks are scoped to a board and subscribe to specific actions:

```ruby
# app/models/webhook.rb
class Webhook < ApplicationRecord
  include Triggerable

  PERMITTED_ACTIONS = %w[
    card_assigned
    card_closed
    card_postponed
    card_auto_postponed
    card_board_changed
    card_published
    card_reopened
    card_sent_back_to_triage
    card_triaged
    card_unassigned
    comment_created
  ].freeze

  has_secure_token :signing_secret

  has_many :deliveries, dependent: :delete_all
  has_one :delinquency_tracker, dependent: :delete

  belongs_to :account, default: -> { board.account }
  belongs_to :board

  serialize :subscribed_actions, type: Array, coder: JSON

  scope :ordered, -> { order(name: :asc, id: :desc) }
  scope :active, -> { where(active: true) }

  after_create :create_delinquency_tracker!

  normalizes :subscribed_actions,
    with: ->(value) { Array.wrap(value).map(&:to_s).uniq & PERMITTED_ACTIONS }
  normalizes :url, with: -> { it.strip }

  validates :name, presence: true
  validate :validate_url

  def activate
    update! active: true unless active?
  end

  def deactivate
    update! active: false
  end

  def for_slack?
    url.match? %r{//hooks\.slack\.com/services/}i
  end

  private
    def validate_url
      uri = URI.parse(url.presence)
      unless %w[ http https ].include?(uri.scheme)
        errors.add :url, "must use http or https"
      end
    rescue URI::InvalidURIError
      errors.add :url, "not a URL"
    end
end
```

Key design decisions:
- `has_secure_token :signing_secret` auto-generates a signing secret per webhook.
- `subscribed_actions` is a JSON array normalized against `PERMITTED_ACTIONS`.
- Webhooks are board-scoped, not account-wide. Each board has its own webhooks.
- `delinquency_tracker` is created on webhook creation to track consecutive failures.

## Triggerable Concern

Handles matching events to webhooks and creating deliveries:

```ruby
# app/models/webhook/triggerable.rb
module Webhook::Triggerable
  extend ActiveSupport::Concern

  included do
    scope :triggered_by, ->(event) {
      where(board: event.board).triggered_by_action(event.action)
    }
    scope :triggered_by_action, ->(action) {
      where("subscribed_actions LIKE ?", "%\"#{action}\"%")
    }
  end

  def trigger(event)
    deliveries.create!(event: event) unless account.cancelled?
  end
end
```

## Webhook Dispatch Job

Uses `ActiveJob::Continuable` for resumable processing across many webhooks:

```ruby
# app/jobs/event/webhook_dispatch_job.rb
class Event::WebhookDispatchJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :webhooks
  discard_on ActiveJob::DeserializationError

  def perform(event)
    step :dispatch do |step|
      Webhook.active.triggered_by(event).find_each(start: step.cursor) do |webhook|
        webhook.trigger(event)
        step.advance! from: webhook.id
      end
    end
  end
end
```

## Webhook Delivery

Each delivery is an independent record with its own state machine and HTTP request:

```ruby
# app/models/webhook/delivery.rb
class Webhook::Delivery < ApplicationRecord
  ENDPOINT_TIMEOUT = 7.seconds
  MAX_RESPONSE_SIZE = 100.kilobytes

  belongs_to :account, default: -> { webhook.account }
  belongs_to :webhook
  belongs_to :event

  store :request, coder: JSON
  store :response, coder: JSON

  enum :state, %w[ pending in_progress completed errored ].index_by(&:itself),
    default: :pending

  scope :ordered, -> { order created_at: :desc, id: :desc }
  scope :stale, -> { where(created_at: ...7.days.ago) }

  after_create_commit :deliver_later

  def deliver_later
    Webhook::DeliveryJob.perform_later(self)
  end

  def deliver
    in_progress!

    self.request[:headers] = headers
    self.response = perform_request
    self.state = :completed
    save!

    webhook.delinquency_tracker.record_delivery_of(self)
  rescue
    errored!
    raise
  end

  def succeeded?
    completed? && response[:error].blank? && response[:code].between?(200, 299)
  end

  def failed?
    (errored? || completed?) && !succeeded?
  end

  private
    def perform_request
      if resolved_ip.nil?
        { error: :private_uri }
      else
        request = Net::HTTP::Post.new(uri, headers)
        request.body = payload
        response = http.request(request)
        { code: response.code.to_i }
      end
    rescue Resolv::ResolvTimeout, Resolv::ResolvError, SocketError
      { error: :dns_lookup_failed }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT
      { error: :connection_timeout }
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET
      { error: :destination_unreachable }
    rescue OpenSSL::SSL::SSLError
      { error: :failed_tls }
    end

    def resolved_ip
      @resolved_ip ||= SsrfProtection.resolve_public_ip(uri.host)
    end

    def uri
      @uri ||= URI(webhook.url)
    end

    def http
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.ipaddr = resolved_ip
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = ENDPOINT_TIMEOUT
        http.read_timeout = ENDPOINT_TIMEOUT
      end
    end

    def headers
      { "User-Agent" => "app/1.0.0 Webhook",
        "Content-Type" => content_type,
        "X-Webhook-Signature" => signature,
        "X-Webhook-Timestamp" => event.created_at.utc.iso8601 }
    end

    def signature
      OpenSSL::HMAC.hexdigest("SHA256", webhook.signing_secret, payload)
    end

    def content_type
      if webhook.for_slack?
        "application/json"
      else
        "application/json"
      end
    end

    def payload
      @payload ||= render_payload(formats: :json)
    end

    def render_payload(**options)
      webhook.renderer.render(
        layout: false, template: "webhooks/event",
        assigns: { event: event }, **options
      ).strip
    end
end
```

### SSRF Protection

Webhook delivery resolves the target host to a public IP before making the
request. If the URL resolves to a private/internal IP, the delivery records
`{ error: :private_uri }` and does not make the request.

```ruby
class SsrfProtection
  PRIVATE_RANGES = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("::1/128"),
  ].freeze

  def self.resolve_public_ip(host)
    ip = Resolv.getaddress(host)
    return nil if PRIVATE_RANGES.any? { |range| range.include?(ip) }
    ip
  rescue Resolv::ResolvError
    nil
  end
end
```

## Delinquency Tracker

Automatically deactivates webhooks after sustained failures:

```ruby
# app/models/webhook/delinquency_tracker.rb
class Webhook::DelinquencyTracker < ApplicationRecord
  DELINQUENCY_THRESHOLD = 10
  DELINQUENCY_DURATION = 1.hour

  belongs_to :account, default: -> { webhook.account }
  belongs_to :webhook

  def record_delivery_of(delivery)
    if delivery.succeeded?
      reset
    else
      mark_first_failure_time if consecutive_failures_count.zero?
      increment!(:consecutive_failures_count, touch: true)
      webhook.deactivate if delinquent?
    end
  end

  private
    def reset
      update_columns consecutive_failures_count: 0, first_failure_at: nil
    end

    def mark_first_failure_time
      update_columns first_failure_at: Time.current
    end

    def delinquent?
      failing_for_too_long? && too_many_consecutive_failures?
    end

    def failing_for_too_long?
      first_failure_at&.before?(DELINQUENCY_DURATION.ago)
    end

    def too_many_consecutive_failures?
      consecutive_failures_count >= DELINQUENCY_THRESHOLD
    end
end
```

A webhook is deactivated when BOTH conditions are met:
1. First failure was more than 1 hour ago
2. 10+ consecutive failures without a single success

A single successful delivery resets the counter entirely.

## Migrations

```ruby
class CreateWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :webhooks, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :board, null: false, type: :uuid
      t.text :url, null: false
      t.string :name
      t.string :signing_secret, null: false
      t.text :subscribed_actions
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :webhooks, [:board_id, :subscribed_actions], length: { subscribed_actions: 255 }
  end
end

class CreateWebhookDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_deliveries, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :webhook, null: false, type: :uuid
      t.references :event, null: false, type: :uuid
      t.string :state, null: false
      t.text :request
      t.text :response

      t.timestamps
    end

    add_index :webhook_deliveries, :created_at
  end
end

class CreateWebhookDelinquencyTrackers < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_delinquency_trackers, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :webhook, null: false, type: :uuid
      t.integer :consecutive_failures_count, default: 0
      t.datetime :first_failure_at

      t.timestamps
    end
  end
end
```

## Stale Delivery Cleanup

Deliveries older than 7 days are cleaned up in batches:

```ruby
class Webhook::Delivery
  def self.cleanup(batch_size: 500, pause: 0.1)
    sleep pause until stale.limit(batch_size).delete_all.zero?
  end
end
```

## Testing Webhooks

```ruby
test "triggers webhook for matching board and action" do
  webhook = webhooks(:card_events)
  event = events(:card_closed)

  assert_difference -> { Webhook::Delivery.count } do
    webhook.trigger(event)
  end
end

test "does not trigger webhook for cancelled accounts" do
  webhook = webhooks(:card_events)
  webhook.account.update!(cancelled: true)
  event = events(:card_closed)

  assert_no_difference -> { Webhook::Delivery.count } do
    webhook.trigger(event)
  end
end

test "delivery includes HMAC signature" do
  delivery = webhook_deliveries(:pending)
  headers = delivery.send(:headers)

  assert headers["X-Webhook-Signature"].present?
  assert headers["X-Webhook-Timestamp"].present?
end

test "delinquency tracker deactivates webhook after threshold" do
  webhook = webhooks(:card_events)
  tracker = webhook.delinquency_tracker
  tracker.update!(
    first_failure_at: 2.hours.ago,
    consecutive_failures_count: 9
  )

  failed_delivery = webhook_deliveries(:failed)
  tracker.record_delivery_of(failed_delivery)

  assert_not webhook.reload.active?
end

test "successful delivery resets delinquency counter" do
  tracker = webhook_delinquency_trackers(:failing)
  tracker.update!(consecutive_failures_count: 5, first_failure_at: 1.hour.ago)

  tracker.record_delivery_of(webhook_deliveries(:succeeded))

  assert_equal 0, tracker.consecutive_failures_count
  assert_nil tracker.first_failure_at
end

test "dispatch job finds webhooks scoped to event board" do
  event = events(:card_closed)

  assert_enqueued_jobs 0, only: Webhook::DeliveryJob do
    # No webhooks on this board
  end
end

test "SSRF protection blocks private IPs" do
  delivery = webhook_deliveries(:pending)
  delivery.webhook.update!(url: "http://192.168.1.1/hook")

  delivery.deliver
  assert_equal "private_uri", delivery.response[:error].to_s
end
```
