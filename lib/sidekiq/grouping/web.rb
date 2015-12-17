require 'sidekiq/web'

module Sidetiq
  module Grouping
    module Web
      VIEWS = File.expand_path('views', File.dirname(__FILE__))

      def self.registered(app)
        app.get "/grouping" do
          @queues = Sidekiq::Grouping::Batch.all_by_queue
          erb File.read(File.join(VIEWS, 'index.erb')), locals: {view_path: VIEWS}
        end

        app.post "/grouping/:name/delete" do
          worker_class, option, queue = Sidekiq::Grouping::Batch.extract_worker_info(params["name"])
          batch = Sidekiq::Grouping::Batch.new(worker_class, option, queue)
          batch.delete
          redirect "#{root_path}/grouping"
        end
      end

    end
  end
end

Sidekiq::Web.register(Sidetiq::Grouping::Web)
Sidekiq::Web.tabs["Grouping"] = "grouping"
