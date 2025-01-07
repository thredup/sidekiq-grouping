# frozen_string_literal: true

module Sidekiq
  module Grouping
    module Config
      include ActiveSupport::Configurable

      def self.options
        if Sidekiq.respond_to?(:[]) # Sidekiq 6.x
          Sidekiq[:grouping] || {}
        elsif Sidekiq.respond_to?(:options) # Sidekiq <= 5.x
          Sidekiq.options[:grouping] || Sidekiq.options["grouping"] || {}
        else # Sidekiq 7.x
          Sidekiq.default_configuration[:grouping] || {}
        end
      end

      config_accessor :enabled do
        options[:enabled] != false
      end

      # Queue size overflow check polling interval
      config_accessor :poll_interval do
        options[:poll_interval] || 3
      end

      config_accessor :batch_flush_interval do
        options[:batch_flush_interval] || 60
      end

      config_accessor :max_records_per_call do
        options[:max_records_per_call] || 200
      end

      config_accessor :max_calls_per_minute do
        options[:max_calls_per_minute] || 30
      end

      # Batch queue flush lock timeout
      config_accessor :lock_ttl do
        options[:lock_ttl] || 1
      end

      # Option to override how Sidekiq::Grouping know about tests env
      config_accessor :tests_env do
        options[:tests_env] || (
          defined?(::Rails) && Rails.respond_to?(:env) && Rails.env.test?
        )
      end
    end
  end
end
