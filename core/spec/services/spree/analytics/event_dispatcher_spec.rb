# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Analytics::EventDispatcher, type: :service do
  describe '#call' do
    let(:order) { create(:order_with_line_items) }
    let(:user) { create(:user) }

    context 'when analytics is enabled' do
      before { allow(Spree::Analytics::Config).to receive(:enabled?).and_return(true) }

      it 'creates an analytics event' do
        expect do
          described_class.call(
            category: :order,
            type: :completed,
            subject: order,
            actor: user
          )
        end.to change(Spree::AnalyticsEvent, :count).by(1)
      end

      it 'returns success with event' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order
        )

        expect(result).to be_success
        expect(result.value).to be_a(Spree::AnalyticsEvent)
        expect(result.value.event_category).to eq('order')
        expect(result.value.event_type).to eq('completed')
      end

      it 'extracts order from subject' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order
        )

        expect(result.value.order).to eq(order)
      end

      it 'extracts product from variant subject' do
        variant = create(:variant)
        result = described_class.call(
          category: :product,
          type: :viewed,
          subject: variant
        )

        expect(result.value.product).to eq(variant.product)
      end

      it 'extracts user from actor' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order,
          actor: user
        )

        expect(result.value.user).to eq(user)
      end

      it 'stores properties and context' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order,
          properties: { total: 100.0 },
          context: { referrer: 'google' }
        )

        expect(result.value.properties).to eq('total' => 100.0)
        expect(result.value.context).to eq('referrer' => 'google')
      end

      it 'sets source from options' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order,
          source: 'api'
        )

        expect(result.value.source).to eq('api')
      end

      it 'defaults source to web' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order
        )

        expect(result.value.source).to eq('web')
      end

      context 'with subscriptions' do
        let!(:subscription) do
          create(:analytics_event_subscription,
                 event_pattern: 'order.completed',
                 active: true)
        end

        it 'dispatches to matching subscriptions' do
          expect_any_instance_of(Spree::AnalyticsEventSubscription)
            .to receive(:execute)

          described_class.call(
            category: :order,
            type: :completed,
            subject: order
          )
        end

        context 'with async tracking enabled' do
          before { allow(Spree::Analytics::Config).to receive(:async_tracking?).and_return(true) }

          it 'logs async dispatch' do
            allow(Rails.logger).to receive(:info)

            described_class.call(
              category: :order,
              type: :completed,
              subject: order
            )

            expect(Rails.logger).to have_received(:info).with(/Queued event/)
          end
        end
      end
    end

    context 'when analytics is disabled' do
      before { allow(Spree::Analytics::Config).to receive(:enabled?).and_return(false) }

      it 'does not create an event' do
        expect do
          described_class.call(
            category: :order,
            type: :completed,
            subject: order
          )
        end.not_to change(Spree::AnalyticsEvent, :count)
      end

      it 'returns success with nil' do
        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order
        )

        expect(result).to be_success
        expect(result.value).to be_nil
      end
    end

    context 'when event creation fails' do
      it 'returns failure' do
        allow(Spree::AnalyticsEvent).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new)

        result = described_class.call(
          category: :order,
          type: :completed,
          subject: order
        )

        expect(result).to be_failure
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        allow(Spree::AnalyticsEvent).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(Spree::AnalyticsEvent.new))

        described_class.call(
          category: :order,
          type: :completed,
          subject: order
        )

        expect(Rails.logger).to have_received(:error).with(/Failed to create event/)
      end
    end
  end
end
