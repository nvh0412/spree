# frozen_string_literal: true

module Spree
  module Analytics
    # CartTracking service module for tracking cart operations
    #
    # Prepend this to cart services to automatically track cart events
    module CartTracking
      # Track item added to cart
      def track_item_added(order, line_item, quantity)
        TrackEvent.cart(
          :item_added,
          order,
          properties: {
            product_id: line_item.product_id,
            variant_id: line_item.variant_id,
            product_name: line_item.product.name,
            sku: line_item.variant.sku,
            quantity: quantity,
            price: line_item.price.to_f,
            total: (line_item.price * quantity).to_f
          },
          user: order.user
        )
      end

      # Track item removed from cart
      def track_item_removed(order, line_item)
        TrackEvent.cart(
          :item_removed,
          order,
          properties: {
            product_id: line_item.product_id,
            variant_id: line_item.variant_id,
            product_name: line_item.product.name,
            quantity: line_item.quantity,
            price: line_item.price.to_f
          },
          user: order.user
        )
      end

      # Track quantity updated
      def track_quantity_updated(order, line_item, old_quantity, new_quantity)
        TrackEvent.cart(
          :quantity_updated,
          order,
          properties: {
            product_id: line_item.product_id,
            variant_id: line_item.variant_id,
            product_name: line_item.product.name,
            old_quantity: old_quantity,
            new_quantity: new_quantity,
            quantity_change: new_quantity - old_quantity,
            price: line_item.price.to_f
          },
          user: order.user
        )
      end

      # Track cart emptied
      def track_cart_emptied(order)
        TrackEvent.cart(
          :emptied,
          order,
          properties: {
            items_count: order.line_items.count,
            total: order.total.to_f
          },
          user: order.user
        )
      end

      # Track cart updated
      def track_cart_updated(order)
        TrackEvent.cart(
          :updated,
          order,
          properties: {
            items_count: order.item_count,
            total: order.total.to_f,
            item_total: order.item_total.to_f
          },
          user: order.user
        )
      end
    end
  end
end
