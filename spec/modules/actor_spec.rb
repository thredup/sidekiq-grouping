require 'spec_helper'

describe Sidekiq::Grouping::Actor do
  subject { Sidekiq::Grouping::Actor }

  before(:each) do
    allow_any_instance_of(described_class).to receive(:link_to_sidekiq_manager)
  end

  context 'calculate_records_per_queue' do
    context 'scenario 1' do
      let(:max_records_per_call) { 7 }
      let(:max_calls_per_minute) { 3 }
      let(:records_to_process) { 37 }
      let(:number_of_batch) { 4 }

      it 'should return 5' do
        params = [max_records_per_call, max_calls_per_minute, records_to_process, number_of_batch]

        result = subject.new.send(:calculate_records_per_queue, *params)

        expect(result).to eq(5)
      end
    end

    context 'scenario 2' do
      let(:max_records_per_call) { 200 }
      let(:max_calls_per_minute) { 1000 }
      let(:records_to_process) { 379 }
      let(:number_of_batch) { 5 }

      it 'should return 75' do
        params = [max_records_per_call, max_calls_per_minute, records_to_process, number_of_batch]

        result = subject.new.send(:calculate_records_per_queue, *params)

        expect(result).to eq(75)
      end
    end

    context 'scenario 2' do
      let(:max_records_per_call) { 20 }
      let(:max_calls_per_minute) { 100 }
      let(:records_to_process) { 7892 }
      let(:number_of_batch) { 8 }

      it 'should return 250' do
        params = [max_records_per_call, max_calls_per_minute, records_to_process, number_of_batch]

        result = subject.new.send(:calculate_records_per_queue, *params)

        expect(result).to eq(250)
      end
    end
  end
end
