# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Order Analytics Tracking Integration', type: :integration do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user) }

  before do
    allow(Spree::Analytics::Config).to receive(:enabled?).and_return(true)
  end

  describe 'order lifecycle tracking' do
    it 'tracks order creation' do
      expect do
        order = create(:order, user: user)
      end.to change(Spree::AnalyticsEvent, :count).by(1)

      event = Spree::AnalyticsEvent.last
      expect(event.event_category).to eq('order')
      expect(event.event_type).to eq('created')
      expect(event.subject).to eq(order)
      expect(event.user).to eq(user)
    end

    it 'tracks order completion' do
      order.update!(state: 'complete', completed_at: Time.current)

      event = Spree::AnalyticsEvent.for_category('order')
                                    .for_type('completed')
                                    .last

      expect(event).not_to be_nil
      expect(event.subject).to eq(order)
      expect(event.property('state')).to eq('complete')
    end

    it 'tracks order cancellation' do
      order.update!(state: 'canceled')

      event = Spree::AnalyticsEvent.for_category('order')
                                    .for_type('canceled')
                                    .last

      expect(event).not_to be_nil
      expect(event.property('new_state')).to eq('canceled')
    end

    it 'tracks payment state changes' do
      order.update!(payment_state: 'paid')

      event = Spree::AnalyticsEvent.for_category('order')
                                    .for_type('payment_state_changed')
                                    .last

      expect(event).not_to be_nil
      expect(event.property('new_payment_state')).to eq('paid')
    end

    it 'tracks shipment state changes' do
      order.update!(shipment_state: 'shipped')

      event = Spree::AnalyticsEvent.for_category('order')
                                    .for_type('shipment_state_changed')
                                    .last

      expect(event).not_to be_nil
      expect(event.property('new_shipment_state')).to eq('shipped')
    end
  end

  describe 'event properties' do
    it 'includes comprehensive order data' do
      order = create(:order_with_line_items, user: user)
      order.update!(state: 'complete', completed_at: Time.current)

      event = Spree::AnalyticsEvent.for_type('completed').last

      expect(event.property('order_number')).to eq(order.number)
      expect(event.property('total')).to eq(order.total.to_f)
      expect(event.property('item_count')).to eq(order.item_count)
      expect(event.property('currency')).to eq(order.currency)
    end
  end

  describe 'multiple events for order lifecycle' do
    it 'creates separate events for each state change' do
      order = create(:order, user: user)

      initial_count = Spree::AnalyticsEvent.for_category('order').count

      order.update!(payment_state: 'paid')
      order.update!(shipment_state: 'shipped')
      order.update!(state: 'complete', completed_at: Time.current)

      final_count = Spree::AnalyticsEvent.for_category('order').count

      # Created, payment_state_changed, shipment_state_changed, completed
      expect(final_count - initial_count).to eq(3)
    end
  end
end
