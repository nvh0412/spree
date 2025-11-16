# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::AnalyticsEvent, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:subject).optional }
    it { is_expected.to belong_to(:actor).optional }
    it { is_expected.to belong_to(:order).optional }
    it { is_expected.to belong_to(:product).optional }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:event_category) }
    it { is_expected.to validate_inclusion_of(:event_category).in_array(described_class::VALID_CATEGORIES) }
    it { is_expected.to validate_inclusion_of(:source).in_array(described_class::VALID_SOURCES).allow_nil }

    it 'validates properties is a Hash' do
      event = build(:analytics_event, properties: 'invalid')
      expect(event).not_to be_valid
      expect(event.errors[:properties]).to include('must be a Hash')
    end

    it 'validates context is a Hash' do
      event = build(:analytics_event, context: 'invalid')
      expect(event).not_to be_valid
      expect(event.errors[:context]).to include('must be a Hash')
    end
  end

  describe 'scopes' do
    let!(:order_event) { create(:analytics_event, event_category: 'order', event_type: 'completed') }
    let!(:cart_event) { create(:analytics_event, event_category: 'cart', event_type: 'item_added') }
    let!(:old_event) { create(:analytics_event, created_at: 2.weeks.ago) }
    let!(:recent_event) { create(:analytics_event, created_at: 1.day.ago) }

    describe '.for_category' do
      it 'returns events for specific category' do
        expect(described_class.for_category('order')).to include(order_event)
        expect(described_class.for_category('order')).not_to include(cart_event)
      end
    end

    describe '.for_type' do
      it 'returns events for specific type' do
        expect(described_class.for_type('completed')).to include(order_event)
        expect(described_class.for_type('completed')).not_to include(cart_event)
      end
    end

    describe '.last_week' do
      it 'returns events from last week' do
        expect(described_class.last_week).to include(recent_event)
        expect(described_class.last_week).not_to include(old_event)
      end
    end

    describe '.between' do
      it 'returns events within date range' do
        results = described_class.between(3.weeks.ago, 1.week.ago)
        expect(results).to include(old_event)
        expect(results).not_to include(recent_event)
      end
    end
  end

  describe '#event_name' do
    it 'returns formatted event name' do
      event = build(:analytics_event, event_category: 'order', event_type: 'completed')
      expect(event.event_name).to eq('order.completed')
    end
  end

  describe '#property' do
    let(:event) { build(:analytics_event, properties: { 'total' => 100.0, 'items' => 5 }) }

    it 'retrieves property value' do
      expect(event.property('total')).to eq(100.0)
      expect(event.property(:items)).to eq(5)
    end

    it 'returns default for missing property' do
      expect(event.property('missing', 'default')).to eq('default')
    end
  end

  describe '#anonymize!' do
    let(:event) do
      create(:analytics_event,
             ip_address: '192.168.1.1',
             user_agent: 'Mozilla/5.0',
             properties: { 'email' => 'user@example.com', 'name' => 'John' })
    end

    it 'removes sensitive data' do
      event.anonymize!
      expect(event.reload.ip_address).to be_nil
      expect(event.user_agent).to be_nil
    end
  end

  describe '.track' do
    context 'when analytics is enabled' do
      before { allow(Spree::Analytics::Config).to receive(:enabled?).and_return(true) }

      it 'creates an event' do
        expect do
          described_class.track('order', 'completed', properties: { total: 100 })
        end.to change(described_class, :count).by(1)
      end

      it 'returns the created event' do
        event = described_class.track('order', 'completed')
        expect(event).to be_a(described_class)
        expect(event.event_category).to eq('order')
        expect(event.event_type).to eq('completed')
      end
    end

    context 'when analytics is disabled' do
      before { allow(Spree::Analytics::Config).to receive(:enabled?).and_return(false) }

      it 'does not create an event' do
        expect do
          described_class.track('order', 'completed')
        end.not_to change(described_class, :count)
      end

      it 'returns nil' do
        expect(described_class.track('order', 'completed')).to be_nil
      end
    end

    context 'when validation fails' do
      it 'logs error and returns nil' do
        allow(Rails.logger).to receive(:error)
        result = described_class.track('invalid_category', 'test')
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(/Analytics Event Error/)
      end
    end
  end

  describe '.event_counts' do
    before do
      create(:analytics_event, event_category: 'order', event_type: 'completed')
      create(:analytics_event, event_category: 'order', event_type: 'completed')
      create(:analytics_event, event_category: 'order', event_type: 'canceled')
      create(:analytics_event, event_category: 'cart', event_type: 'item_added')
    end

    it 'returns counts grouped by type' do
      counts = described_class.event_counts(category: 'order')
      expect(counts['completed']).to eq(2)
      expect(counts['canceled']).to eq(1)
    end
  end

  describe '.unique_users' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }

    before do
      create(:analytics_event, user: user1, created_at: 2.days.ago)
      create(:analytics_event, user: user1, created_at: 1.day.ago)
      create(:analytics_event, user: user2, created_at: 1.day.ago)
      create(:analytics_event, user: nil, created_at: 1.day.ago)
    end

    it 'returns unique user count for time period' do
      expect(described_class.unique_users(start_time: 3.days.ago)).to eq(2)
    end
  end

  describe '.cleanup_old_events' do
    before do
      create(:analytics_event, created_at: 100.days.ago)
      create(:analytics_event, created_at: 50.days.ago)
      create(:analytics_event, created_at: 1.day.ago)
    end

    it 'deletes events older than specified period' do
      expect do
        described_class.cleanup_old_events(older_than: 90.days)
      end.to change(described_class, :count).by(-1)
    end
  end
end
