# frozen_string_literal: true

require "sidekiq/web"

module Sidekiq
  module Grouping
    module Web
      VIEWS = File.expand_path("views", File.dirname(__FILE__))

      def self.registered(app)
        app.get "/grouping" do
          @queues = Sidekiq::Grouping::Batch.all_by_queue
          erb File.read(File.join(VIEWS, "index.erb")),
              locals: { view_path: VIEWS }
        end

        app.post "/grouping/:name/delete" do
          worker_class, option, queue = Sidekiq::Grouping::Batch.extract_worker_klass_and_queue(params["name"])
          batch = Sidekiq::Grouping::Batch.new(worker_class, option, queue)
          batch.delete
          redirect "#{root_path}grouping"
        end
      end
    end
  end
end

Sidekiq::Web.register(Sidekiq::Grouping::Web)
Sidekiq::Web.tabs["Grouping"] = "grouping"
