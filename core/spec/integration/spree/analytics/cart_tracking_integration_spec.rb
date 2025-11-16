# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Cart Analytics Tracking Integration', type: :integration do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user) }
  let(:variant) { create(:variant) }

  before do
    allow(Spree::Analytics::Config).to receive(:enabled?).and_return(true)
    # Prepend the analytics module to the service
    Spree::Cart::AddItem.prepend(Spree::Cart::AddItemWithAnalytics)
  end

  describe 'cart operations tracking' do
    it 'tracks item added to cart' do
      expect do
        Spree::Cart::AddItem.call(
          order: order,
          variant: variant,
          quantity: 2
        )
      end.to change { Spree::AnalyticsEvent.for_category('cart').count }.by(1)

      event = Spree::AnalyticsEvent.for_category('cart')
                                    .for_type('item_added')
                                    .last

      expect(event).not_to be_nil
      expect(event.subject).to eq(order)
      expect(event.property('product_id')).to eq(variant.product_id)
      expect(event.property('variant_id')).to eq(variant.id)
      expect(event.property('quantity')).to eq(2)
    end

    it 'includes product details in event properties' do
      result = Spree::Cart::AddItem.call(
        order: order,
        variant: variant,
        quantity: 1
      )

      event = Spree::AnalyticsEvent.for_category('cart').last

      expect(event.property('product_name')).to eq(variant.product.name)
      expect(event.property('sku')).to eq(variant.sku)
      expect(event.property('price')).to be_a(Float)
    end

    it 'does not fail cart operation if analytics fails' do
      allow(Spree::Analytics::TrackEvent).to receive(:cart).and_raise(StandardError)
      allow(Rails.logger).to receive(:error)

      result = Spree::Cart::AddItem.call(
        order: order,
        variant: variant,
        quantity: 1
      )

      expect(result).to be_success
      expect(Rails.logger).to have_received(:error).with(/Failed to track item added/)
    end
  end

  describe 'event context extraction' do
    it 'associates event with order and user' do
      Spree::Cart::AddItem.call(
        order: order,
        variant: variant,
        quantity: 1
      )

      event = Spree::AnalyticsEvent.last

      expect(event.order).to eq(order)
      expect(event.user).to eq(user)
    end

    it 'extracts product from variant' do
      Spree::Cart::AddItem.call(
        order: order,
        variant: variant,
        quantity: 1
      )

      event = Spree::AnalyticsEvent.last

      expect(event.product).to eq(variant.product)
    end
  end
end
