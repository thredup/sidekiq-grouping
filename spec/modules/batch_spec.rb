# frozen_string_literal: true

require "spec_helper"

describe Sidekiq::Grouping::Batch do
  subject(:batch_service) { described_class }

  context "adding" do
    it "must enqueue unbatched worker" do
      RegularWorker.perform_async("foo_option", "bar")
      expect(RegularWorker).to have_enqueued_sidekiq_job("foo_option", "bar")
    end

    it "must not enqueue batched worker" do
      BatchedSizeWorker.perform_async("foo_option", "bar")
      expect_batch(BatchedSizeWorker, "batched_size", "foo_option")
    end
  end

  context "checking if should flush" do
    it "checks this scenario" do
      batch = subject.new(BatchedSizeWorker.name, "batched_size", "foo_option")

      # empty batch, the dates are not set.
      expect(batch).not_to be_could_flush
      BatchedSizeWorker.perform_async("foo_option", "bar")
      # non empty batch, dates are initiated but the batch is not flushed
      expect(batch).not_to be_could_flush
      Timecop.travel(1.minute.since)
      # we are 1min from the last check with a non empty batch => flushable
      expect(batch).to be_could_flush
    end
  end

  context "flushing" do
    it "must put worker to queue on flush" do
      batch = subject.new(BatchedSizeWorker.name, "batched_size", "foo_option")

      expect(batch).not_to be_could_flush
      10.times { |n| BatchedSizeWorker.perform_async("foo_option", "bar#{n}") }
      batch.flush(2)
      expect(BatchedSizeWorker).to have_enqueued_sidekiq_job(
        {
          "queue_option" => "foo_option", "chunks" => [[%w[foo_option bar0],
                                                        %w[
                                                          foo_option bar1
                                                        ]]]
        }
      )
      expect(batch.size).to eq(8)
    end
  end

  context "with similar args" do
    context "option batch_unique = true" do
      it "enqueues once" do
        batch = subject.new(
          BatchedUniqueArgsWorker.name,
          "batched_unique_args",
          "foo_option"
        )
        3.times do
          BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
        end
        expect(batch.size).to eq(1)
      end

      it "enqueues once each unique set of args" do
        batch = subject.new(
          BatchedUniqueArgsWorker.name,
          "batched_unique_args",
          "foo_option"
        )
        3.times do
          BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
        end
        6.times do
          BatchedUniqueArgsWorker.perform_async("foo_option", "baz", 1)
        end
        3.times do
          BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
        end
        2.times do
          BatchedUniqueArgsWorker.perform_async("foo_option", "baz", 3)
        end
        7.times do
          BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
        end
        expect(batch.size).to eq(3)
      end

      context "flushing" do
        it "works" do
          batch = subject.new(
            BatchedUniqueArgsWorker.name,
            "batched_unique_args",
            "foo_option"
          )
          2.times do
            BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
          end
          2.times do
            BatchedUniqueArgsWorker.perform_async("foo_option", "baz", 1)
          end
          batch.flush(batch.size)
          expect(batch.size).to eq(0)
        end

        it "allows to enqueue again after flush" do
          batch = subject.new(
            BatchedUniqueArgsWorker.name,
            "batched_unique_args",
            "foo_option"
          )
          2.times do
            BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
          end
          2.times do
            BatchedUniqueArgsWorker.perform_async("foo_option", "baz", 1)
          end
          batch.flush(batch.size)
          BatchedUniqueArgsWorker.perform_async("foo_option", "bar", 1)
          BatchedUniqueArgsWorker.perform_async("foo_option", "baz", 1)
          expect(batch.size).to eq(2)
        end
      end
    end

    context "batch_unique is not specified" do
      it "enqueues all" do
        batch = subject.new(
          BatchedSizeWorker.name,
          "batched_size",
          "foo_option"
        )
        3.times { BatchedSizeWorker.perform_async("foo_option", "bar", 1) }
        expect(batch.size).to eq(3)
      end
    end
  end

  context "when inline mode" do
    before do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Sidekiq::Grouping::Middleware
      end
    end

    it "must pass args to worker as array" do
      Sidekiq::Testing.inline! do
        expect_any_instance_of(BatchedSizeWorker)
          .to receive(:perform).with(
            {
              "chunks" => [[["foo_option", "bar",
                             1]]], "queue_option" => "foo_option"
            }
          )

        BatchedSizeWorker.perform_async("foo_option", "bar", 1)
      end
    end

    it "must not pass args to worker as array" do
      Sidekiq::Testing.inline! do
        expect_any_instance_of(RegularWorker).to receive(:perform).with(1)

        RegularWorker.perform_async(1)
      end
    end
  end

  private

  def expect_batch(klass, queue, queue_option)
    expect(klass).not_to have_enqueued_sidekiq_job("foo_option", "bar")
    batch = subject.new(klass.name, queue, queue_option)
    stats = subject.all
    expect(batch.size).to eq(1)
    expect(stats.size).to eq(1)
    expect(stats.first.worker_class).to eq(klass.name)
    expect(stats.first.queue).to eq(queue)
    expect(batch.pluck(batch.size)).to eq [%w[foo_option bar]]
  end
end
