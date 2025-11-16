# frozen_string_literal: true

module Spree
  module Analytics
    # OrderTracking concern for tracking order-related events
    #
    # Include this in Spree::Order to enable automatic event tracking
    module OrderTracking
      extend ActiveSupport::Concern

      included do
        # Track order state changes
        after_commit :track_order_created, on: :create
        after_commit :track_order_state_change, if: :saved_change_to_state?
        after_commit :track_payment_state_change, if: :saved_change_to_payment_state?
        after_commit :track_shipment_state_change, if: :saved_change_to_shipment_state?
      end

      private

      def track_order_created
        Spree::Analytics::TrackEvent.order(
          :created,
          self,
          properties: order_properties,
          user: user
        )
      end

      def track_order_state_change
        event_type = case state
                     when 'complete'
                       :completed
                     when 'canceled'
                       :canceled
                     when 'returned'
                       :returned
                     else
                       :state_changed
                     end

        Spree::Analytics::TrackEvent.order(
          event_type,
          self,
          properties: order_properties.merge(
            previous_state: state_before_last_save,
            new_state: state
          ),
          user: user
        )
      end

      def track_payment_state_change
        Spree::Analytics::TrackEvent.order(
          :payment_state_changed,
          self,
          properties: order_properties.merge(
            previous_payment_state: payment_state_before_last_save,
            new_payment_state: payment_state
          ),
          user: user
        )
      end

      def track_shipment_state_change
        Spree::Analytics::TrackEvent.order(
          :shipment_state_changed,
          self,
          properties: order_properties.merge(
            previous_shipment_state: shipment_state_before_last_save,
            new_shipment_state: shipment_state
          ),
          user: user
        )
      end

      def order_properties
        {
          order_number: number,
          state: state,
          payment_state: payment_state,
          shipment_state: shipment_state,
          total: total.to_f,
          item_total: item_total.to_f,
          item_count: item_count,
          currency: currency,
          completed_at: completed_at,
          channel: channel
        }
      end
    end
  end
end
