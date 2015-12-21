module Sidekiq
  module Grouping
    module Config
      include ActiveSupport::Configurable

      config_accessor :enabled, :poll_interval, :batch_flush_interval, :max_records_per_call, :max_calls_per_minute, :lock_ttl

      ### Default values ###
      self.config.enabled = true

      # Queue check polling interval
      self.config.poll_interval = 3

      # Flush the queue every x seconds
      self.config.batch_flush_interval = 60

      # How many records max should be grouped together
      self.config.max_records_per_call = 200

      # How many calls can be made per minute
      self.config.max_calls_per_minute = 30

      # Batch queue flush lock timeout
      self.config.lock_ttl = 1
    end
  end
end
