# Spree Analytics Infrastructure

## Overview

This document describes the analytics infrastructure implementation for Spree Commerce. The system provides comprehensive event tracking capabilities for monitoring user behavior, e-commerce operations, and system performance.

## Architecture

### Core Components

1. **AnalyticsEvent Model** - Stores individual tracking events
2. **EventDispatcher Service** - Publishes and routes events to subscribers
3. **TrackEvent Service** - Convenience wrapper for common tracking scenarios
4. **EventSubscription Model** - Manages event handlers and observers
5. **AnalyticsMetric Model** - Stores pre-aggregated metrics for performance

### Design Principles

- **Non-invasive**: Analytics tracking doesn't break core application flow
- **Extensible**: Easy to add new event types and subscribers
- **Performant**: Async processing and pre-aggregated metrics
- **GDPR-compliant**: Built-in data anonymization and retention policies
- **Type-safe**: Comprehensive validations and error handling

## Database Schema

### `spree_analytics_events`

Primary table for storing all tracked events.

| Column | Type | Description |
|--------|------|-------------|
| `event_type` | string | Specific event (e.g., "completed", "viewed") |
| `event_category` | string | Event category (order, cart, product, user, etc.) |
| `subject_type/id` | polymorphic | Primary object of the event |
| `actor_type/id` | polymorphic | Who triggered the event |
| `order_id` | integer | Associated order (if applicable) |
| `product_id` | integer | Associated product (if applicable) |
| `user_id` | integer | Associated user (if applicable) |
| `properties` | jsonb | Event-specific data |
| `context` | jsonb | Additional context (referrer, UTM, etc.) |
| `session_id` | string | Session identifier |
| `source` | string | Event source (web, api, mobile, admin) |
| `created_at` | timestamp | Event timestamp |

**Indexes:**
- `event_type`, `event_category` for filtering
- `created_at` for time-series queries
- Composite indexes for common query patterns
- `session_id`, `user_id` for user journey analysis

### `spree_analytics_event_subscriptions`

Manages event handlers using pattern matching.

| Column | Type | Description |
|--------|------|-------------|
| `event_pattern` | string | Pattern to match (e.g., "order.*", "cart.item_added") |
| `subscriber_class` | string | Handler class name |
| `active` | boolean | Enable/disable subscription |
| `priority` | integer | Execution order (higher = first) |
| `configuration` | jsonb | Subscriber-specific config |

### `spree_analytics_metrics`

Pre-aggregated metrics for dashboard performance.

| Column | Type | Description |
|--------|------|-------------|
| `metric_type` | string | Type of metric (revenue, orders, etc.) |
| `dimension` | string | Time dimension (hourly, daily, weekly, monthly) |
| `metric_date` | date | Date of metric |
| `data` | jsonb | Aggregated data |

## Usage

### Tracking Events

#### Manual Tracking

```ruby
# Simple tracking
Spree::Analytics::TrackEvent.call(
  category: :order,
  type: :completed,
  subject: order,
  actor: current_user,
  properties: { total: order.total, items: order.item_count },
  session_id: session.id
)

# Convenience methods
Spree::Analytics::TrackEvent.order(:completed, order, actor: current_user)
Spree::Analytics::TrackEvent.product(:viewed, product, actor: current_user)
Spree::Analytics::TrackEvent.cart(:item_added, order, properties: { quantity: 2 })
```

#### Automatic Tracking

The system automatically tracks:

**Order Events:**
- `order.created` - Order created
- `order.completed` - Order completed
- `order.canceled` - Order canceled
- `order.payment_state_changed` - Payment status changed
- `order.shipment_state_changed` - Shipment status changed

**Cart Events:**
- `cart.item_added` - Item added to cart
- `cart.item_removed` - Item removed from cart
- `cart.quantity_updated` - Item quantity changed

### Querying Events

```ruby
# Find all order completion events
Spree::AnalyticsEvent.for_category('order').for_type('completed')

# Events from last week
Spree::AnalyticsEvent.last_week

# Events for specific user
Spree::AnalyticsEvent.for_user(user).recent

# Custom date range
Spree::AnalyticsEvent.between(1.month.ago, Time.current)

# Event counts by type
Spree::AnalyticsEvent.event_counts(category: 'order')
# => { "completed" => 150, "canceled" => 5 }

# Unique users in period
Spree::AnalyticsEvent.unique_users(start_time: 1.week.ago)
# => 1250
```

### Event Subscriptions

Create handlers that react to events:

```ruby
# Create subscription
Spree::AnalyticsEventSubscription.create!(
  event_pattern: 'order.*',  # Matches all order events
  subscriber_class: 'Analytics::OrderMetricsHandler',
  active: true,
  priority: 10
)

# Handler class example
class Analytics::OrderMetricsHandler
  def call(event)
    # Process event (runs async in production)
    if event.event_type == 'completed'
      update_revenue_metrics(event)
      send_to_data_warehouse(event)
    end
  end

  private

  def update_revenue_metrics(event)
    # Update aggregated metrics
  end

  def send_to_data_warehouse(event)
    # Push to external analytics
  end
end
```

Pattern matching supports:
- Exact match: `"order.completed"`
- Wildcard category: `"order.*"` (all order events)
- Wildcard type: `"*.completed"` (all completion events)
- Match all: `"*"`

### Configuration

Override defaults in `config/initializers/spree.rb`:

```ruby
Spree::Analytics::Config.configure do |config|
  config.enabled = true
  config.async_tracking = Rails.env.production?
  config.data_retention_days = 90
  config.track_ip_addresses = false  # Enhanced privacy
  config.anonymize_after_days = 30   # GDPR compliance
end
```

### Data Management

#### Cleanup Old Events

```ruby
# Delete events older than 90 days
Spree::AnalyticsEvent.cleanup_old_events(older_than: 90.days)

# Recommended: Run via cron job
# 0 2 * * * cd /app && rake analytics:cleanup
```

#### Anonymize Events (GDPR)

```ruby
# Anonymize specific event
event.anonymize!

# Anonymize old events
Spree::AnalyticsEvent
  .where('created_at < ?', 30.days.ago)
  .find_each(&:anonymize!)
```

## Extending the System

### Adding New Event Categories

1. Add to `VALID_CATEGORIES` in `AnalyticsEvent`:

```ruby
VALID_CATEGORIES = %w[
  order cart product user payment shipment promotion search system
  wishlist review rating
].freeze
```

2. Create tracking concern (optional):

```ruby
module Spree::Analytics::WishlistTracking
  extend ActiveSupport::Concern

  included do
    after_commit :track_wishlist_created, on: :create
  end

  private

  def track_wishlist_created
    Spree::Analytics::TrackEvent.call(
      category: :wishlist,
      type: :created,
      subject: self,
      user: user
    )
  end
end
```

### Custom Metrics

```ruby
# Record daily revenue metric
Spree::AnalyticsMetric.record(
  metric_type: 'revenue',
  dimension: 'daily',
  metric_date: Date.today,
  data: {
    total: 15_000.50,
    orders_count: 45,
    avg_order_value: 333.34,
    currency: 'USD'
  }
)

# Query metrics
today_revenue = Spree::AnalyticsMetric
  .for_type('revenue')
  .for_dimension('daily')
  .for_date(Date.today)
  .first

puts today_revenue.metric_value(:total) # => 15000.50
```

## Performance Considerations

### Database Optimization

1. **Partitioning**: Consider partitioning `spree_analytics_events` by date for large datasets
2. **Archiving**: Move old events to separate archive table
3. **Indexes**: Default indexes cover common queries; add custom indexes for specific needs

### Query Performance

```ruby
# Good: Use pre-aggregated metrics
daily_revenue = AnalyticsMetric.for_type('revenue').for_date(Date.today).first

# Bad: Real-time aggregation on large dataset
daily_revenue = AnalyticsEvent
  .for_category('order')
  .for_type('completed')
  .today
  .sum('properties->>"total"')
```

### Async Processing

In production, event subscribers run asynchronously:

```ruby
# Create ActiveJob for subscriber execution
class AnalyticsSubscriberJob < ApplicationJob
  queue_as :analytics

  def perform(subscription_id, event_id)
    subscription = Spree::AnalyticsEventSubscription.find(subscription_id)
    event = Spree::AnalyticsEvent.find(event_id)
    subscription.execute(event)
  end
end
```

## Testing

### Model Tests

```ruby
require 'spec_helper'

RSpec.describe Spree::AnalyticsEvent do
  it 'tracks order completion' do
    order = create(:order)
    event = described_class.track('order', 'completed', subject: order)

    expect(event.event_name).to eq('order.completed')
    expect(event.subject).to eq(order)
  end
end
```

### Service Tests

```ruby
RSpec.describe Spree::Analytics::EventDispatcher do
  it 'creates event and notifies subscribers' do
    subscription = create(:analytics_event_subscription, event_pattern: 'order.*')

    expect do
      described_class.call(category: :order, type: :completed, subject: order)
    end.to change(Spree::AnalyticsEvent, :count).by(1)
  end
end
```

### Integration Tests

```ruby
RSpec.describe 'Order tracking' do
  it 'tracks order lifecycle' do
    order = create(:order)
    order.update!(state: 'complete')

    events = Spree::AnalyticsEvent.for_category('order').recent
    expect(events.map(&:event_type)).to include('created', 'completed')
  end
end
```

## Security & Privacy

### GDPR Compliance

1. **Right to erasure**: Use `anonymize!` to redact personal data
2. **Data retention**: Automated cleanup after retention period
3. **Consent tracking**: Store consent status in `context` field

```ruby
event = AnalyticsEvent.track('user', 'registered',
  subject: user,
  context: { consent: { analytics: true, marketing: false } }
)
```

### PII Protection

Configure to avoid collecting sensitive data:

```ruby
config.track_ip_addresses = false
config.track_user_agents = false
```

Sensitive fields in `properties` are automatically redacted by `anonymize!`.

## Monitoring & Observability

### Key Metrics to Monitor

1. **Event volume**: Events created per hour/day
2. **Processing latency**: Time from event to subscriber completion
3. **Subscriber failures**: Failed subscription executions
4. **Storage growth**: Database size and growth rate

### Logging

All analytics operations log to Rails logger:

```ruby
[Analytics] Failed to create event: Validation failed
[Analytics] Queued event order.completed for OrderMetricsHandler
[Analytics] Subscriber execution failed: Connection timeout
```

## Migration Guide

### From Existing Trackers

If migrating from `spree_analytics_trackers`:

1. Run the migration: `rake db:migrate`
2. Configure subscriptions to forward events to Google Analytics/Segment
3. Gradually deprecate old tracker implementation

### Backward Compatibility

This implementation is non-breaking:
- Existing code continues to work
- Analytics is opt-in via configuration
- Can run alongside existing analytics solutions

## Troubleshooting

### Events Not Being Created

Check configuration:
```ruby
Spree::Analytics::Config.enabled? # => should be true
```

Check logs for validation errors:
```bash
grep "Analytics Event Error" log/production.log
```

### Subscribers Not Executing

Verify subscription is active:
```ruby
Spree::AnalyticsEventSubscription.active.pluck(:event_pattern, :subscriber_class)
```

Check subscriber class exists:
```ruby
'YourSubscriberClass'.constantize.new
```

### Performance Issues

1. Verify async processing is enabled
2. Check database indexes
3. Consider archiving old events
4. Use pre-aggregated metrics instead of real-time queries

## Future Enhancements

Potential improvements for future iterations:

1. **Real-time dashboards**: WebSocket-powered live metrics
2. **Anomaly detection**: ML-based unusual pattern detection
3. **A/B testing framework**: Built-in experimentation tracking
4. **Customer journey analytics**: Session replay and funnel analysis
5. **Predictive analytics**: Churn prediction, CLV estimation
6. **Data warehouse integration**: Automated sync to BigQuery/Redshift
7. **GraphQL API**: Query events via GraphQL endpoint

## Contributing

When adding new analytics features:

1. Follow existing patterns (Service Module, concerns)
2. Add comprehensive tests (unit + integration)
3. Update documentation
4. Consider performance impact
5. Ensure GDPR compliance
6. Add to changelog

## License

This implementation is part of Spree Commerce and follows the same BSD-3-Clause license.
