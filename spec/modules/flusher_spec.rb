# frozen_string_literal: true

require "spec_helper"

describe Sidekiq::Grouping::Flusher do
  context "calculate_records_per_queue" do
    context "scenario 1" do
      let(:max_records_per_call) { 7 }
      let(:max_calls_per_minute) { 3 }
      let(:records_to_process) { 37 }
      let(:number_of_batch) { 4 }

      it "returns 5" do
        params = [max_records_per_call, max_calls_per_minute,
                  records_to_process, number_of_batch]

        result = subject.send(:calculate_records_per_queue, *params)

        expect(result).to eq(5)
      end
    end

    context "scenario 2" do
      let(:max_records_per_call) { 200 }
      let(:max_calls_per_minute) { 1000 }
      let(:records_to_process) { 379 }
      let(:number_of_batch) { 5 }

      it "returns 75" do
        params = [max_records_per_call, max_calls_per_minute,
                  records_to_process, number_of_batch]

        result = subject.send(:calculate_records_per_queue, *params)

        expect(result).to eq(75)
      end
    end

    context "scenario 2" do
      let(:max_records_per_call) { 20 }
      let(:max_calls_per_minute) { 100 }
      let(:records_to_process) { 7892 }
      let(:number_of_batch) { 8 }

      it "returns 250" do
        params = [max_records_per_call, max_calls_per_minute,
                  records_to_process, number_of_batch]

        result = subject.send(:calculate_records_per_queue, *params)

        expect(result).to eq(250)
      end
    end
  end
end
