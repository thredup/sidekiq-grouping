module Sidekiq
  module Grouping
    class Middleware
      def call(worker_class, msg, queue, redis_pool = nil)
        worker_class = worker_class.classify.constantize if worker_class.is_a?(String)
        options = worker_class.get_sidekiq_options

        batch = options['grouping'] && options['grouping'] == true

        passthrough =
          msg['args'] &&
          msg['args'].is_a?(Array) &&
          msg['args'].try(:first) == true

        retrying = msg['failed_at'].present?

        return yield unless batch

        if !(passthrough || retrying)
          queue_option = msg['args'].first
          add_to_batch(worker_class, queue, queue_option, msg, redis_pool)
        else
          msg['args'].shift if passthrough
          yield
        end
      end

      private

      def add_to_batch(worker_class, queue, queue_option, msg, redis_pool = nil)
        Sidekiq::Grouping::Batch
          .new(worker_class.name, queue, queue_option, redis_pool)
          .add(msg['args'])

        nil
      end
    end
  end
end
