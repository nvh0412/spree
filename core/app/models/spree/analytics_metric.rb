# frozen_string_literal: true

module Spree
  # AnalyticsMetric model for storing pre-aggregated metrics
  #
  # This model stores aggregated analytics data to improve query performance
  # for dashboards and reports. Metrics are computed via background jobs.
  #
  # @example Create a daily metric
  #   AnalyticsMetric.create!(
  #     metric_type: 'revenue',
  #     dimension: 'daily',
  #     metric_date: Date.today,
  #     data: { total: 15000.50, orders_count: 45, avg_order_value: 333.34 }
  #   )
  #
  class AnalyticsMetric < Spree::Base
    DIMENSIONS = %w[hourly daily weekly monthly yearly].freeze
    METRIC_TYPES = %w[
      revenue
      orders
      products
      users
      cart_abandonment
      conversion
      traffic
    ].freeze

    # Validations
    validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES }
    validates :dimension, presence: true, inclusion: { in: DIMENSIONS }
    validates :metric_date, presence: true
    validates :data, presence: true
    validate :validate_data_is_hash

    # Scopes
    scope :for_type, ->(type) { where(metric_type: type) }
    scope :for_dimension, ->(dimension) { where(dimension: dimension) }
    scope :for_date, ->(date) { where(metric_date: date) }
    scope :recent, -> { order(metric_date: :desc) }
    scope :between, ->(start_date, end_date) { where(metric_date: start_date..end_date) }

    # Get metric value by key
    #
    # @param key [String, Symbol] data key
    # @param default [Object] default value
    # @return [Object]
    def metric_value(key, default = 0)
      data.fetch(key.to_s, default)
    end

    # Update metric data (merge with existing)
    #
    # @param new_data [Hash] data to merge
    # @return [Boolean]
    def merge_data!(new_data)
      update!(data: data.merge(new_data))
    end

    # Class methods
    class << self
      # Get or create metric for date and type
      #
      # @param metric_type [String] type of metric
      # @param dimension [String] time dimension
      # @param metric_date [Date] date for metric
      # @return [AnalyticsMetric]
      def find_or_initialize_for(metric_type:, dimension:, metric_date:)
        find_or_initialize_by(
          metric_type: metric_type,
          dimension: dimension,
          metric_date: metric_date
        )
      end

      # Compute and store metric
      #
      # @param metric_type [String] type of metric
      # @param dimension [String] time dimension
      # @param metric_date [Date] date for metric
      # @param data [Hash] metric data
      # @return [AnalyticsMetric]
      def record(metric_type:, dimension:, metric_date:, data:)
        metric = find_or_initialize_for(
          metric_type: metric_type,
          dimension: dimension,
          metric_date: metric_date
        )
        metric.data = data
        metric.save!
        metric
      end
    end

    private

    def validate_data_is_hash
      errors.add(:data, 'must be a Hash') unless data.is_a?(Hash)
    end
  end
end
