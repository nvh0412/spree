# frozen_string_literal: true

module Spree
  module Cart
    # Decorator for AddItem service that adds analytics tracking
    #
    # This extends the base AddItem service to automatically track cart events
    # without modifying the core service logic.
    module AddItemWithAnalytics
      include Spree::Analytics::CartTracking

      def call(order:, variant:, quantity: nil, options: {})
        result = super

        if result.success?
          track_add_item_event(result)
        end

        result
      end

      private

      def track_add_item_event(result)
        line_item = result.value[:line_item]
        quantity = result.value[:line_item_created] ? line_item.quantity : result.value[:options][:quantity] || 1
        order = result.value[:order]

        track_item_added(order, line_item, quantity)
      rescue StandardError => e
        # Don't let analytics errors break the cart
        Rails.logger.error("[Analytics] Failed to track item added: #{e.message}")
      end
    end
  end
end
