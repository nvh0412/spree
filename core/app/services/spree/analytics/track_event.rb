# frozen_string_literal: true

module Spree
  module Analytics
    # TrackEvent - Simple service for tracking events
    #
    # This is a convenience wrapper around EventDispatcher for common tracking scenarios
    #
    # @example Track a product view
    #   Spree::Analytics::TrackEvent.call(
    #     category: :product,
    #     type: :viewed,
    #     subject: product,
    #     actor: current_user,
    #     properties: { source: 'search_results' }
    #   )
    #
    class TrackEvent
      prepend Spree::ServiceModule::Base

      def call(**options)
        EventDispatcher.call(**options)
      end

      # Convenience methods for common events
      class << self
        # Track order event
        def order(type, order, **options)
          call(
            category: :order,
            type: type,
            subject: order,
            **options
          )
        end

        # Track cart event
        def cart(type, order, **options)
          call(
            category: :cart,
            type: type,
            subject: order,
            **options
          )
        end

        # Track product event
        def product(type, product, **options)
          call(
            category: :product,
            type: type,
            subject: product,
            **options
          )
        end

        # Track payment event
        def payment(type, payment, **options)
          call(
            category: :payment,
            type: type,
            subject: payment,
            **options
          )
        end

        # Track user event
        def user(type, user, **options)
          call(
            category: :user,
            type: type,
            subject: user,
            **options
          )
        end

        # Track shipment event
        def shipment(type, shipment, **options)
          call(
            category: :shipment,
            type: type,
            subject: shipment,
            **options
          )
        end

        # Track search event
        def search(query, results_count:, **options)
          call(
            category: :search,
            type: :performed,
            properties: {
              query: query,
              results_count: results_count
            }.merge(options[:properties] || {}),
            **options.except(:properties)
          )
        end
      end
    end
  end
end
