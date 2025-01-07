# frozen_string_literal: true

class RegularWorker
  include Sidekiq::Worker

  def perform(foo); end
end

class BatchedSizeWorker
  include Sidekiq::Worker

  sidekiq_options grouping: true, queue: :batched_size, max_calls_per_min: 2

  def perform(foo); end
end

class BatchedUniqueArgsWorker
  include Sidekiq::Worker

  sidekiq_options(
    grouping: true, queue: :batched_unique_args, max_calls_per_min: 3, batch_unique: true
  )

  def perform(foo); end
end
