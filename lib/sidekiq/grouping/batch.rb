module Sidekiq
  module Grouping
    class Batch
      def initialize(worker_class, queue, queue_option, redis_pool = nil)
        @worker_class = worker_class
        @queue = queue
        @queue_option = queue_option
        @name = "#{worker_class.underscore}:#{queue_option}:#{queue}"
        @redis = Sidekiq::Grouping::Redis.new
      end

      attr_reader :name, :worker_class, :queue, :queue_option

      def add(msg)
        msg = msg.to_json
        @redis.push_msg(@name, msg, enqueue_similar_once?) if should_add? msg
      end

      def should_add? msg
        return true unless enqueue_similar_once?
        !@redis.enqueued?(@name, msg)
      end

      def size
        @redis.batch_size(@name)
      end

      def pluck(pluck_size)
        if @redis.lock(@name)
          @redis.pluck(@name, pluck_size).map { |value| JSON.parse(value) }
        end
      end

      def flush(size)
        return unless (chunk = pluck(size))

        info "Flushing #{@name} of #{size} records"

        group_size = worker_class_options['max_records_per_call'] || Sidekiq::Grouping::Config.max_records_per_call

        Sidekiq::Client.push(
          'class' => @worker_class,
          'queue' => @queue,
          'args' => [true, { queue_option: @queue_option, chunks: split_by_size(chunk, group_size) }]
        )

        set_current_time_as_last
      end

      def worker_class_constant
        @worker_class.constantize
      end

      def worker_class_options
        worker_class_constant.get_sidekiq_options
      rescue NameError
        {}
      end

      def could_flush?
        could_flush_on_time?
      end

      def last_execution_time
        last_time = @redis.get_last_execution_time(@name)
        Time.parse(last_time) if last_time
      end

      def next_execution_time
        interval = worker_class_options['batch_flush_interval'] || Sidekiq::Grouping::Config.batch_flush_interval
        last_time = last_execution_time
        last_time + interval.seconds if last_time
      end

      def delete
        @redis.delete(@name)
      end

      private

      def could_flush_on_time?
        return false if size.zero?

        last_time = last_execution_time
        next_time = next_execution_time

        if last_time.blank?
          set_current_time_as_last
          false
        else
          next_time < Time.now if next_time
        end
      end

      def enqueue_similar_once?
        worker_class_options['batch_unique'] == true
      end

      def set_current_time_as_last
        @redis.set_last_execution_time(@name, Time.now)
      end

      # input: %w(1 2 3 4 5 6 7 8 9 10), 3
      # output: [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["10"]]
      def split_by_size(chunk, size)
        chunk.each_slice(size).to_a
      end

      class << self
        def all
          redis = Sidekiq::Grouping::Redis.new

          redis.batches.map do |name|
            new(*extract_worker_info(name))
          end
        end

        def all_by_queue
          all.inject({}) do |batches, batch|
            batches[batch.queue.to_s] ||= []
            batches[batch.queue.to_s] << batch
            batches
          end
        end

        def extract_worker_info(name)
          klass, option, queue = name.split(':')
          [klass.camelize, queue, option]
        end
      end
    end
  end
end
