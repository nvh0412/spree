# frozen_string_literal: true

module Spree
  module Analytics
    # EventDispatcher - Central service for publishing and dispatching analytics events
    #
    # This service handles:
    # - Publishing events to the database
    # - Notifying subscribers
    # - Managing async vs sync execution
    #
    # @example Dispatch an event
    #   EventDispatcher.call(
    #     category: 'order',
    #     type: 'completed',
    #     subject: order,
    #     actor: current_user,
    #     properties: { total: order.total }
    #   )
    #
    class EventDispatcher
      prepend Spree::ServiceModule::Base

      # Dispatch an analytics event
      #
      # @param category [String, Symbol] event category
      # @param type [String, Symbol] event type
      # @param options [Hash] additional event data
      # @option options [Object] :subject the primary object of the event
      # @option options [Object] :actor who triggered the event
      # @option options [Hash] :properties event-specific data
      # @option options [Hash] :context additional context data
      # @option options [String] :session_id current session identifier
      # @option options [String] :source event source (web, api, mobile, admin)
      # @return [Spree::ServiceModule::Result]
      def call(category:, type:, **options)
        return success(nil) unless Spree::Analytics::Config.enabled?

        run :create_event, category, type, options
        run :dispatch_to_subscribers

        success(@event)
      end

      private

      def create_event(category, type, options)
        @event = Spree::AnalyticsEvent.create!(
          event_category: category.to_s,
          event_type: type.to_s,
          subject: options[:subject],
          actor: options[:actor],
          order: extract_order(options),
          product: extract_product(options),
          user: extract_user(options),
          properties: options[:properties] || {},
          context: options[:context] || {},
          session_id: options[:session_id],
          source: options[:source] || 'web',
          user_agent: options[:user_agent],
          ip_address: Spree::Analytics::Config.track_ip_addresses? ? options[:ip_address] : nil,
          referer: options[:referer],
          response_time_ms: options[:response_time_ms]
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[Analytics] Failed to create event: #{e.message}")
        failure(e)
      end

      def dispatch_to_subscribers
        subscriptions = Spree::AnalyticsEventSubscription.matching(@event.event_name)

        subscriptions.each do |subscription|
          if Spree::Analytics::Config.async_tracking?
            # Queue background job (would integrate with ActiveJob)
            dispatch_async(subscription, @event)
          else
            dispatch_sync(subscription, @event)
          end
        end
      end

      def dispatch_async(subscription, event)
        # In production, this would use ActiveJob:
        # AnalyticsSubscriberJob.perform_later(subscription.id, event.id)
        Rails.logger.info("[Analytics] Queued event #{event.event_name} for #{subscription.subscriber_class}")
      end

      def dispatch_sync(subscription, event)
        subscription.execute(event)
      rescue StandardError => e
        Rails.logger.error("[Analytics] Subscriber execution failed: #{e.message}")
      end

      # Extract order from various contexts
      def extract_order(options)
        return options[:order] if options[:order].is_a?(Spree::Order)
        return options[:subject] if options[:subject].is_a?(Spree::Order)

        if options[:subject].respond_to?(:order)
          options[:subject].order
        end
      end

      # Extract product from various contexts
      def extract_product(options)
        return options[:product] if options[:product].is_a?(Spree::Product)
        return options[:subject] if options[:subject].is_a?(Spree::Product)

        if options[:subject].is_a?(Spree::Variant)
          options[:subject].product
        elsif options[:subject].is_a?(Spree::LineItem)
          options[:subject].product
        end
      end

      # Extract user from various contexts
      def extract_user(options)
        return options[:user] if options[:user].is_a?(Spree.user_class)
        return options[:actor] if options[:actor].is_a?(Spree.user_class)

        if options[:subject].respond_to?(:user)
          options[:subject].user
        end
      end
    end
  end
end
