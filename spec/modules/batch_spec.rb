require 'spec_helper'

describe Sidekiq::Grouping::Batch do
  subject { Sidekiq::Grouping::Batch }

  context 'adding' do
    it 'must enqueue unbatched worker' do
       RegularWorker.perform_async('foo_option', 'bar')
       expect(RegularWorker).to have_enqueued_job('foo_option', 'bar')
    end

    it 'must not enqueue batched worker' do
      BatchedSizeWorker.perform_async('foo_option', 'bar')
      expect_batch(BatchedSizeWorker, 'batched_size', 'foo_option')
    end
  end

  context 'checking if should flush' do
    it 'should check this scenario' do
      batch = subject.new(BatchedSizeWorker.name, 'batched_size', 'foo_option')

      # empty batch, the dates are not set.
      expect(batch.could_flush?).to be_falsy
      BatchedSizeWorker.perform_async('foo_option', 'bar')
      # non empty batch, dates are initiated but the batch is not flushed
      expect(batch.could_flush?).to be_falsy
      Timecop.travel(1.minute.since)
      # we are 1min from the last check with a non empty batch => flushable
      expect(batch.could_flush?).to be_truthy
    end
  end

  context 'flushing' do
    it 'must put worker to queue on flush' do
      batch = subject.new(BatchedSizeWorker.name, 'batched_size', 'foo_option')

      expect(batch.could_flush?).to be_falsy
      10.times { |n| BatchedSizeWorker.perform_async('foo_option', "bar#{n}") }
      batch.flush(2)
      expect(BatchedSizeWorker).to have_enqueued_job({ "queue_option" => "foo_option", "chunks" => [[["foo_option", "bar0"], ["foo_option", "bar1"]]] })
      expect(batch.size).to eq(8)
    end
  end

  context 'with similar args' do
    context 'option batch_unique = true' do
      it 'enqueues once' do
        batch = subject.new(BatchedUniqueArgsWorker.name, 'batched_unique_args', 'foo_option')
        3.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'bar', 1) }
        expect(batch.size).to eq(1)
      end

      it 'enqueues once each unique set of args' do
        batch = subject.new(BatchedUniqueArgsWorker.name, 'batched_unique_args', 'foo_option')
        3.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'bar', 1) }
        6.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'baz', 1) }
        3.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'bar', 1) }
        2.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'baz', 3) }
        7.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'bar', 1) }
        expect(batch.size).to eq(3)
      end

      context 'flushing' do

        it 'works' do
          batch = subject.new(BatchedUniqueArgsWorker.name, 'batched_unique_args', 'foo_option')
          2.times { BatchedUniqueArgsWorker.perform_async('foo_option' 'bar', 1) }
          2.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'baz', 1) }
          batch.flush(batch.size)
          expect(batch.size).to eq(0)
        end

        it 'allows to enqueue again after flush' do
          batch = subject.new(BatchedUniqueArgsWorker.name, 'batched_unique_args', 'foo_option')
          2.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'bar', 1) }
          2.times { BatchedUniqueArgsWorker.perform_async('foo_option', 'baz', 1) }
          batch.flush(batch.size)
          BatchedUniqueArgsWorker.perform_async('foo_option', 'bar', 1)
          BatchedUniqueArgsWorker.perform_async('foo_option', 'baz', 1)
          expect(batch.size).to eq(2)
        end
      end

    end

    context 'batch_unique is not specified' do
      it 'enqueues all' do
        batch = subject.new(BatchedSizeWorker.name, 'batched_size', 'foo_option')
        3.times { BatchedSizeWorker.perform_async('foo_option', 'bar', 1) }
        expect(batch.size).to eq(3)
      end
    end
  end

  private
  def expect_batch(klass, queue, queue_option)
    expect(klass).to_not have_enqueued_job('foo_option', 'bar')
    batch = subject.new(klass.name, queue, queue_option)
    stats = subject.all
    expect(batch.size).to eq(1)
    expect(stats.size).to eq(1)
    expect(stats.first.worker_class).to eq(klass.name)
    expect(stats.first.queue).to eq(queue)
    expect(batch.pluck(batch.size)).to eq [['foo_option', 'bar']]
  end
end
