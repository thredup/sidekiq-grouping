module Sidekiq
  module Grouping
    class Middleware
      def call(worker_class, msg, queue, redis_pool = nil)
        sanitized_worker_class = sanitize_worker_class(worker_class)
        options = sanitized_worker_class.get_sidekiq_options

        return yield unless batch?(options)
        return if inline_test? && !Sidekiq::Testing.server_middleware.exists?(self.class) # Skips batching in inline mode unless the server middleware is in the Sidekiq::Testing middleware chain.

        queue_option = get_queue_option(msg)

        if passthrough?(msg) || retrying?(msg)
          msg['args'].shift if passthrough?(msg)
          yield
        elsif inline_test? # Simulates the server side batching when it's an inline test + the middleware is in the Sidekiq::Testing middleware chain.
          msg['args'] = [true, { 'queue_option' => queue_option, 'chunks' => [[msg['args']]] }]
          yield
        else
          add_to_batch(sanitized_worker_class, queue, queue_option, msg, redis_pool)
        end
      end

      private

      def add_to_batch(worker_class, queue, queue_option, msg, redis_pool = nil)
        Sidekiq::Grouping::Batch
          .new(worker_class.name, queue, queue_option, redis_pool)
          .add(msg['args'])

        nil
      end

      def sanitize_worker_class(worker_class)
        if worker_class.is_a?(String)
          worker_class.camelize.constantize
        elsif worker_class.is_a?(Object) # Sidekiq::Testing inline mode + middleware is in the middleware chain. The job is an instance of the worker class here (pls don't ask why).
          worker_class.class
        else
          worker_class
        end
      end

      def get_queue_option(msg)
        msg['args'].first
      end

      def inline_test?
        defined?(Sidekiq::Testing) && Sidekiq::Testing.inline?
      end

      def batch?(options)
        options['grouping'] && options['grouping'] == true
      end

      def passthrough?(msg)
        msg['args'] &&
          msg['args'].is_a?(Array) &&
          msg['args'].try(:first) == true
      end

      def retrying?(msg)
        msg['failed_at'].present?
      end
    end
  end
end
