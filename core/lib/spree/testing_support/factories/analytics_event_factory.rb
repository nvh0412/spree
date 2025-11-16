# frozen_string_literal: true

FactoryBot.define do
  factory :analytics_event, class: 'Spree::AnalyticsEvent' do
    event_category { 'order' }
    event_type { 'created' }
    properties { {} }
    context { {} }
    source { 'web' }
    session_id { SecureRandom.hex(16) }

    trait :order_completed do
      event_category { 'order' }
      event_type { 'completed' }
      association :subject, factory: :order
      association :order, factory: :order
      properties do
        {
          order_number: subject.number,
          total: subject.total.to_f,
          item_count: subject.item_count
        }
      end
    end

    trait :cart_item_added do
      event_category { 'cart' }
      event_type { 'item_added' }
      association :subject, factory: :order
      association :product, factory: :product
      properties do
        {
          product_id: product.id,
          quantity: 1,
          price: 10.0
        }
      end
    end

    trait :product_viewed do
      event_category { 'product' }
      event_type { 'viewed' }
      association :subject, factory: :product
      association :product, factory: :product
      properties do
        {
          product_name: product.name,
          price: product.price.to_f
        }
      end
    end

    trait :with_user do
      association :user, factory: :user
      association :actor, factory: :user
    end

    trait :with_session do
      session_id { SecureRandom.hex(16) }
      ip_address { '192.168.1.1' }
      user_agent { 'Mozilla/5.0' }
    end
  end

  factory :analytics_event_subscription, class: 'Spree::AnalyticsEventSubscription' do
    event_pattern { 'order.*' }
    subscriber_class { 'TestSubscriber' }
    active { true }
    priority { 0 }
    configuration { {} }

    # Define a simple test subscriber class
    before(:build) do
      unless Object.const_defined?('TestSubscriber')
        class TestSubscriber
          def call(event); end
        end
      end
    end
  end

  factory :analytics_metric, class: 'Spree::AnalyticsMetric' do
    metric_type { 'revenue' }
    dimension { 'daily' }
    metric_date { Date.today }
    data { { total: 0, count: 0 } }
  end
end
