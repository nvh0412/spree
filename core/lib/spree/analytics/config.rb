# frozen_string_literal: true

module Spree
  module Analytics
    # Configuration for analytics system
    #
    # @example Configure analytics
    #   Spree::Analytics::Config.configure do |config|
    #     config.enabled = true
    #     config.async_tracking = true
    #     config.data_retention_days = 90
    #   end
    #
    class Config
      include Singleton

      attr_accessor :enabled,
                    :async_tracking,
                    :data_retention_days,
                    :batch_size,
                    :track_ip_addresses,
                    :track_user_agents,
                    :anonymize_after_days

      def initialize
        @enabled = true
        @async_tracking = true
        @data_retention_days = 365
        @batch_size = 100
        @track_ip_addresses = true
        @track_user_agents = true
        @anonymize_after_days = 30
      end

      class << self
        def configure
          yield instance
        end

        def enabled?
          instance.enabled
        end

        def async_tracking?
          instance.async_tracking
        end

        def track_ip_addresses?
          instance.track_ip_addresses
        end

        def track_user_agents?
          instance.track_user_agents
        end

        def data_retention_days
          instance.data_retention_days
        end

        def batch_size
          instance.batch_size
        end

        def anonymize_after_days
          instance.anonymize_after_days
        end
      end
    end
  end
end
