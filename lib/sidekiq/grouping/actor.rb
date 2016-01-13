module Sidekiq
  module Grouping
    class Actor
      include Sidekiq::Grouping::Logging
      include ::Celluloid

      def initialize
        link_to_sidekiq_manager
      end

      private

      def start_polling
        return unless Sidekiq::Grouping::Config.enabled
        interval = Sidekiq::Grouping::Config.poll_interval
        info "Start polling of queue batches every #{interval} seconds"
        every(interval) { flush_batches }
      end

      def flush_batches
        methods = {}

        Sidekiq::Grouping::Batch.all.map do |batch|
          next unless batch.could_flush?

          method_name = batch.worker_class.to_s

          unless methods[method_name]
            methods[method_name] = {
              batches: [],
              records: 0
            }
          end

          methods[method_name][:batches] << batch
          methods[method_name][:records] += batch.size
        end

        methods.each do |method, options|
          job_class = method.classify.constantize
          max_records_per_call = job_class.get_sidekiq_options["max_records_per_call"] || Sidekiq::Grouping::Config.max_records_per_call
          max_calls_per_minute = job_class.get_sidekiq_options["max_calls_per_minute"] || Sidekiq::Grouping::Config.max_calls_per_minute

          records_per_queue = calculate_records_per_queue(max_records_per_call, max_calls_per_minute, options[:records], options[:batches].length)

          methods[method][:flushable_records] = records_per_queue
        end

        flush(methods)
      end

      def calculate_records_per_queue(max_records_per_call, max_calls_per_minute, number_of_records, number_of_batch)
        number_of_calls = number_of_records / max_records_per_call
        number_of_calls += 1 if number_of_records % max_records_per_call > 0

        if number_of_calls > max_calls_per_minute
          number_of_records_to_process = max_calls_per_minute * max_records_per_call
        else
          number_of_records_to_process = number_of_records
        end

        number_of_records_to_process / number_of_batch
      end

      def link_to_sidekiq_manager
        Sidekiq::CLI.instance.launcher.manager.link(current_actor)
        start_polling
      rescue NoMethodError
        debug "Can't link #{self.class.name}. Sidekiq::Manager not running. Retrying in 5 seconds ..."
        after(5) { link_to_sidekiq_manager }
      end

      # The 'methods' argument should be like {
      # "WorkerName": {
      #   batches: ["WorkerName:queue_option:queue", "WorkerName2:queue_option2:queue2"],
      #   flushable_records_per_queue: 50 }
      # }
      def flush(methods)
        return unless methods.any?

        methods.each do |method, options|
          names = options[:batches].map { |batch| "#{batch.worker_class} in #{batch.queue} with option #{batch.queue_option}" }
          info "Trying to flush batched queues: #{names.join(',')}"

          options[:batches].each { |batch| batch.flush(options[:flushable_records]) }
        end
      end
    end
  end
end
