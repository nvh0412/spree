# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::AnalyticsEventSubscription, type: :model do
  describe 'validations' do
    subject { build(:analytics_event_subscription) }

    it { is_expected.to validate_presence_of(:event_pattern) }
    it { is_expected.to validate_presence_of(:subscriber_class) }
    it { is_expected.to validate_numericality_of(:priority).only_integer }

    it 'validates subscriber class exists' do
      subscription = build(:analytics_event_subscription, subscriber_class: 'NonExistentClass')
      expect(subscription).not_to be_valid
      expect(subscription.errors[:subscriber_class]).to include("class 'NonExistentClass' not found")
    end

    it 'validates pattern format' do
      subscription = build(:analytics_event_subscription, event_pattern: 'invalid pattern!')
      expect(subscription).not_to be_valid
      expect(subscription.errors[:event_pattern]).to include('can only contain letters, numbers, dots, and asterisks')
    end

    it 'validates uniqueness of pattern and subscriber combination' do
      create(:analytics_event_subscription, event_pattern: 'order.*', subscriber_class: 'TestSubscriber')
      duplicate = build(:analytics_event_subscription, event_pattern: 'order.*', subscriber_class: 'TestSubscriber')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_sub) { create(:analytics_event_subscription, active: true, priority: 10) }
    let!(:inactive_sub) { create(:analytics_event_subscription, active: false, priority: 5) }

    describe '.active' do
      it 'returns only active subscriptions' do
        expect(described_class.active).to include(active_sub)
        expect(described_class.active).not_to include(inactive_sub)
      end
    end

    describe '.by_priority' do
      it 'orders by priority descending' do
        expect(described_class.by_priority.first).to eq(active_sub)
      end
    end
  end

  describe '#matches?' do
    it 'matches exact pattern' do
      subscription = build(:analytics_event_subscription, event_pattern: 'order.completed')
      expect(subscription.matches?('order.completed')).to be true
      expect(subscription.matches?('order.canceled')).to be false
    end

    it 'matches wildcard pattern' do
      subscription = build(:analytics_event_subscription, event_pattern: 'order.*')
      expect(subscription.matches?('order.completed')).to be true
      expect(subscription.matches?('order.canceled')).to be true
      expect(subscription.matches?('cart.updated')).to be false
    end

    it 'matches all events with *' do
      subscription = build(:analytics_event_subscription, event_pattern: '*')
      expect(subscription.matches?('order.completed')).to be true
      expect(subscription.matches?('cart.updated')).to be true
    end

    it 'matches complex patterns' do
      subscription = build(:analytics_event_subscription, event_pattern: '*.completed')
      expect(subscription.matches?('order.completed')).to be true
      expect(subscription.matches?('payment.completed')).to be true
      expect(subscription.matches?('order.canceled')).to be false
    end
  end

  describe '.matching' do
    before do
      create(:analytics_event_subscription, event_pattern: 'order.*', active: true, priority: 10)
      create(:analytics_event_subscription, event_pattern: 'order.completed', active: true, priority: 20)
      create(:analytics_event_subscription, event_pattern: 'cart.*', active: true, priority: 5)
      create(:analytics_event_subscription, event_pattern: 'order.completed', active: false, priority: 30)
    end

    it 'returns matching active subscriptions ordered by priority' do
      matches = described_class.matching('order.completed')
      expect(matches.count).to eq(2)
      expect(matches.first.priority).to eq(20)
      expect(matches.last.priority).to eq(10)
    end

    it 'excludes non-matching patterns' do
      matches = described_class.matching('order.completed')
      expect(matches.map(&:event_pattern)).not_to include('cart.*')
    end

    it 'excludes inactive subscriptions' do
      matches = described_class.matching('order.completed')
      inactive = matches.find { |s| s.active == false }
      expect(inactive).to be_nil
    end
  end
end
