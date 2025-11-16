# frozen_string_literal: true

module Spree
  # AnalyticsEvent model for tracking user interactions and system events
  #
  # This model provides a flexible, high-performance event tracking system that can
  # capture any type of event within the Spree e-commerce platform.
  #
  # @example Track an order completion
  #   AnalyticsEvent.create!(
  #     event_type: 'completed',
  #     event_category: 'order',
  #     subject: order,
  #     actor: current_user,
  #     properties: { total: order.total, items_count: order.line_items.count },
  #     session_id: request.session.id
  #   )
  #
  # @example Query events
  #   AnalyticsEvent.for_category('order').last_week
  #   AnalyticsEvent.for_user(user).where(event_type: 'completed')
  #
  class AnalyticsEvent < Spree::Base
    # Event categories - can be extended
    VALID_CATEGORIES = %w[
      order
      cart
      product
      user
      payment
      shipment
      promotion
      search
      system
    ].freeze

    # Common sources
    VALID_SOURCES = %w[web api mobile admin background].freeze

    # Associations
    belongs_to :subject, polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true
    belongs_to :order, class_name: 'Spree::Order', optional: true
    belongs_to :product, class_name: 'Spree::Product', optional: true
    belongs_to :user, class_name: Spree.user_class.to_s, optional: true

    # Validations
    validates :event_type, presence: true, length: { maximum: 100 }
    validates :event_category, presence: true, inclusion: { in: VALID_CATEGORIES }
    validates :source, inclusion: { in: VALID_SOURCES }, allow_nil: true
    validates :session_id, length: { maximum: 255 }
    validates :properties, :context, presence: true
    validate :validate_json_structure

    # Scopes
    scope :for_category, ->(category) { where(event_category: category) }
    scope :for_type, ->(type) { where(event_type: type) }
    scope :for_user, ->(user) { where(user: user) }
    scope :for_session, ->(session_id) { where(session_id: session_id) }
    scope :for_source, ->(source) { where(source: source) }
    scope :recent, -> { order(created_at: :desc) }
    scope :oldest, -> { order(created_at: :asc) }

    # Time-based scopes
    scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
    scope :yesterday, -> { where(created_at: 1.day.ago.all_day) }
    scope :last_week, -> { where('created_at >= ?', 1.week.ago) }
    scope :last_month, -> { where('created_at >= ?', 1.month.ago) }
    scope :between, ->(start_time, end_time) { where(created_at: start_time..end_time) }

    # Subject type scopes
    scope :for_orders, -> { where(subject_type: 'Spree::Order') }
    scope :for_products, -> { where(subject_type: 'Spree::Product') }
    scope :for_carts, -> { for_category('cart') }

    # Returns the full event name (category.type)
    #
    # @return [String] formatted event name
    def event_name
      "#{event_category}.#{event_type}"
    end

    # Check if event has a specific property
    #
    # @param key [String, Symbol] property key
    # @return [Boolean]
    def property?(key)
      properties.key?(key.to_s)
    end

    # Get property value with default
    #
    # @param key [String, Symbol] property key
    # @param default [Object] default value if key doesn't exist
    # @return [Object]
    def property(key, default = nil)
      properties.fetch(key.to_s, default)
    end

    # Get context value with default
    #
    # @param key [String, Symbol] context key
    # @param default [Object] default value if key doesn't exist
    # @return [Object]
    def context_value(key, default = nil)
      context.fetch(key.to_s, default)
    end

    # Anonymize sensitive data for GDPR compliance
    #
    # @return [Boolean]
    def anonymize!
      update!(
        ip_address: nil,
        user_agent: nil,
        user_id: nil,
        actor_id: nil,
        actor_type: nil,
        properties: anonymize_hash(properties),
        context: anonymize_hash(context)
      )
    end

    # Class methods
    class << self
      # Track a new event (preferred method for creating events)
      #
      # @param event_category [String] category of the event
      # @param event_type [String] type of the event
      # @param options [Hash] additional event data
      # @return [AnalyticsEvent, nil] created event or nil if disabled
      def track(event_category, event_type, **options)
        return nil unless Spree::Analytics::Config.enabled?

        create!(
          event_category: event_category.to_s,
          event_type: event_type.to_s,
          **options
        )
      rescue ActiveRecord::RecordInvalid => e
        # Log error but don't raise - analytics shouldn't break application flow
        Rails.logger.error("Analytics Event Error: #{e.message}")
        nil
      end

      # Get event count grouped by type
      #
      # @param category [String] optional category filter
      # @return [Hash] event counts by type
      def event_counts(category: nil)
        relation = category ? for_category(category) : all
        relation.group(:event_type).count
      end

      # Get unique users count for time period
      #
      # @param start_time [Time] start of period
      # @param end_time [Time] end of period
      # @return [Integer] unique user count
      def unique_users(start_time: 1.week.ago, end_time: Time.current)
        between(start_time, end_time).distinct.count(:user_id)
      end

      # Cleanup old events (for data retention policies)
      #
      # @param older_than [ActiveSupport::Duration] time threshold
      # @return [Integer] number of deleted records
      def cleanup_old_events(older_than: 90.days)
        where('created_at < ?', older_than.ago).delete_all
      end
    end

    private

    def validate_json_structure
      errors.add(:properties, 'must be a Hash') unless properties.is_a?(Hash)
      errors.add(:context, 'must be a Hash') unless context.is_a?(Hash)
    end

    # Anonymize sensitive fields in hash
    def anonymize_hash(hash)
      sensitive_keys = %w[email name phone address credit_card]
      hash.transform_values do |value|
        sensitive_keys.any? { |key| hash.key?(key) } ? '[REDACTED]' : value
      end
    end
  end
end
