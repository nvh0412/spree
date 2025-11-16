# frozen_string_literal: true

class CreateSpreeAnalyticsEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_analytics_events do |t|
      t.string :event_type, null: false, index: true
      t.string :event_category, null: false, index: true

      # Polymorphic subject - what the event is about
      t.references :subject, polymorphic: true, index: true

      # Actor - who triggered the event (usually a user)
      t.references :actor, polymorphic: true, index: true

      # Context references for common e-commerce entities
      t.references :order, foreign_key: { to_table: :spree_orders }, index: true
      t.references :product, foreign_key: { to_table: :spree_products }, index: true
      t.references :user, foreign_key: { to_table: :spree_users }, index: true

      # Event metadata
      t.jsonb :properties, default: {}, null: false
      t.jsonb :context, default: {}, null: false

      # Tracking information
      t.string :session_id, index: true
      t.string :source, default: 'web' # web, api, mobile, admin
      t.string :user_agent
      t.string :ip_address
      t.string :referer

      # Performance tracking
      t.integer :response_time_ms

      t.timestamps

      # Index for time-series queries
      t.index :created_at
      t.index [:event_category, :event_type, :created_at], name: 'index_analytics_events_on_category_type_time'
      t.index [:user_id, :created_at], name: 'index_analytics_events_on_user_time'
      t.index [:session_id, :created_at], name: 'index_analytics_events_on_session_time'
    end

    create_table :spree_analytics_event_subscriptions do |t|
      t.string :event_pattern, null: false # e.g., "order.*", "cart.item_added"
      t.string :subscriber_class, null: false
      t.boolean :active, default: true, null: false
      t.integer :priority, default: 0, null: false
      t.jsonb :configuration, default: {}

      t.timestamps

      t.index :active
      t.index [:event_pattern, :active], name: 'index_analytics_subscriptions_on_pattern_active'
    end

    # Aggregated metrics table for performance
    create_table :spree_analytics_metrics do |t|
      t.string :metric_type, null: false
      t.string :dimension, null: false # daily, weekly, monthly
      t.date :metric_date, null: false
      t.jsonb :data, default: {}, null: false

      t.timestamps

      t.index [:metric_type, :dimension, :metric_date], unique: true, name: 'index_analytics_metrics_unique'
    end
  end
end
