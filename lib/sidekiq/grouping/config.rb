module Sidekiq::Grouping::Config
  include ActiveSupport::Configurable

  def self.options
    Sidekiq.options["grouping"] || {}
  end

  # Queue size overflow check polling interval
  config_accessor :poll_interval do
    options[:poll_interval] || 3
  end

  # Batch queue flush lock timeout
  config_accessor :lock_ttl do
    options[:lock_ttl] || 1
  end

  # How many records max should be grouped together
  config_accessor :max_records_per_call do
    options[:max_records_per_call] || 200
  end

  # How many calls can be made per minute
  config_accessor :max_calls_per_minute do
    options[:max_calls_per_minute] || 30
  end
end
