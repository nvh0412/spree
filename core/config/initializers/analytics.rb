# frozen_string_literal: true

# Analytics Infrastructure Initialization
#
# This initializer sets up the Spree analytics infrastructure with sensible defaults.
# Override these settings in your application's config/initializers/spree.rb

Spree::Analytics::Config.configure do |config|
  # Enable/disable analytics tracking globally
  # Default: true
  config.enabled = true

  # Use asynchronous event processing (recommended for production)
  # When true, event subscribers are processed in background jobs
  # Default: true
  config.async_tracking = Rails.env.production?

  # Data retention period in days
  # Events older than this will be eligible for cleanup
  # Default: 365 (1 year)
  config.data_retention_days = 365

  # Batch size for bulk operations
  # Used when processing multiple events or metrics
  # Default: 100
  config.batch_size = 100

  # Track IP addresses
  # Set to false for enhanced privacy compliance
  # Default: true
  config.track_ip_addresses = true

  # Track user agents
  # Set to false for enhanced privacy compliance
  # Default: true
  config.track_user_agents = true

  # Anonymize events after N days (GDPR compliance)
  # Sensitive data will be redacted after this period
  # Default: 30
  config.anonymize_after_days = 30
end

# Prepend analytics tracking to services
Rails.application.config.to_prepare do
  # Enable cart analytics tracking
  Spree::Cart::AddItem.prepend(Spree::Cart::AddItemWithAnalytics) if defined?(Spree::Cart::AddItem)

  # Enable order analytics tracking
  Spree::Order.include(Spree::Analytics::OrderTracking) if defined?(Spree::Order)
end
