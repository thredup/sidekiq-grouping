# frozen_string_literal: true

module Sidekiq
  module Grouping
    class Flusher
      def flush(force: false)
        all_methods = Sidekiq::Grouping::Batch.all.each_with_object({}) do |batch, methods|
          next methods if !batch.could_flush? && !force

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

        all_methods.each do |method, options|
          job_class = method.camelize.constantize
          max_records_per_call = job_class.get_sidekiq_options["max_records_per_call"] ||
                                 Sidekiq::Grouping::Config.max_records_per_call
          max_calls_per_minute = job_class.get_sidekiq_options["max_calls_per_minute"] ||
                                 Sidekiq::Grouping::Config.max_calls_per_minute

          records_per_queue = calculate_records_per_queue(
            max_records_per_call,
            max_calls_per_minute,
            options[:records],
            options[:batches].length
          )

          all_methods[method][:flushable_records] = records_per_queue
        end

        flush_concrete(all_methods)
      end

      def force_flush_for_test!
        unless Sidekiq::Grouping::Config.tests_env
          Sidekiq::Grouping.logger.warn(
            "**************************************************"
          )
          Sidekiq::Grouping.logger.warn(
            "⛔️ force_flush_for_test! for testing API, " \
            "but this is not the test environment. " \
            "Please check your environment or " \
            "change 'tests_env' to cover this one"
          )
          Sidekiq::Grouping.logger.warn(
            "**************************************************"
          )
        end

        flush(force: true)
      end

      private

      def calculate_records_per_queue(max_records_per_call,
                                      max_calls_per_minute, number_of_records, number_of_batch)
        number_of_calls = number_of_records / max_records_per_call
        number_of_calls += 1 if (number_of_records % max_records_per_call).positive?

        number_of_records_to_process = if number_of_calls > max_calls_per_minute
                                         max_calls_per_minute * max_records_per_call
                                       else
                                         number_of_records
                                       end

        number_of_records_to_process / number_of_batch
      end

      # The 'methods' argument should be like {
      # "WorkerName": {
      #   batches: ["WorkerName:queue_option:queue", "WorkerName2:queue_option2:queue2"],
      #   flushable_records_per_queue: 50 }
      # }
      def flush_concrete(methods)
        return unless methods.any?

        methods.each_value do |options|
          names = options[:batches].map do |batch|
            "#{batch.worker_class} in #{batch.queue} with option #{batch.queue_option}"
          end

          unless Sidekiq::Grouping::Config.tests_env
            Sidekiq::Grouping.logger.info(
              "[Sidekiq::Grouping] Trying to flush batched queues: " \
              "#{names.join(',')}"
            )
          end

          options[:batches].each do |batch|
            batch.flush(options[:flushable_records])
          end
        end
      end
    end
  end
end
