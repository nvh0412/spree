# frozen_string_literal: true

module Spree
  # EventSubscription model for managing event handlers
  #
  # Subscriptions allow external systems or internal handlers to react to events
  # using a pattern-matching system. Handlers are executed asynchronously via
  # background jobs to avoid blocking the main application flow.
  #
  # @example Create a subscription
  #   EventSubscription.create!(
  #     event_pattern: 'order.*',
  #     subscriber_class: 'Spree::Analytics::Handlers::OrderMetrics',
  #     active: true,
  #     priority: 10
  #   )
  #
  # @example Match events
  #   subscription.matches?('order.completed') # => true
  #   subscription.matches?('cart.updated')    # => false
  #
  class AnalyticsEventSubscription < Spree::Base
    # Validations
    validates :event_pattern, presence: true, uniqueness: { scope: :subscriber_class }
    validates :subscriber_class, presence: true
    validates :priority, numericality: { only_integer: true }
    validate :validate_subscriber_class_exists
    validate :validate_pattern_format

    # Scopes
    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
    scope :by_priority, -> { order(priority: :desc) }
    scope :for_pattern, ->(pattern) { where('event_pattern = ? OR event_pattern = ?', pattern, '*') }

    # Check if this subscription matches a given event name
    #
    # @param event_name [String] full event name (e.g., 'order.completed')
    # @return [Boolean]
    def matches?(event_name)
      return true if event_pattern == '*'

      if event_pattern.include?('*')
        pattern_regex = Regexp.new("^#{event_pattern.gsub('*', '.*')}$")
        !!(event_name =~ pattern_regex)
      else
        event_pattern == event_name
      end
    end

    # Get the subscriber handler instance
    #
    # @return [Object] subscriber instance
    def subscriber
      @subscriber ||= subscriber_class.constantize.new
    end

    # Execute the subscriber for an event
    #
    # @param event [AnalyticsEvent] the event to process
    # @return [Boolean] success status
    def execute(event)
      return false unless active?
      return false unless matches?(event.event_name)

      subscriber.call(event)
      true
    rescue StandardError => e
      Rails.logger.error("Subscription execution failed: #{e.message}")
      false
    end

    # Class methods
    class << self
      # Find all subscriptions matching an event name
      #
      # @param event_name [String] full event name
      # @return [ActiveRecord::Relation]
      def matching(event_name)
        active.by_priority.select { |sub| sub.matches?(event_name) }
      end
    end

    private

    def validate_subscriber_class_exists
      subscriber_class.constantize
    rescue NameError
      errors.add(:subscriber_class, "class '#{subscriber_class}' not found")
    end

    def validate_pattern_format
      return if event_pattern.blank?

      unless event_pattern =~ /\A[\w.*]+\z/
        errors.add(:event_pattern, 'can only contain letters, numbers, dots, and asterisks')
      end
    end
  end
end
