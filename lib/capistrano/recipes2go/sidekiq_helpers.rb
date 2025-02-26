module Capistrano
  module Recipes2go
    module SidekiqHelpers

      def for_each_process(reverse = false)
        services = sidekiq_services
        services.reverse! if reverse
        services.each_with_index do |service_file, idx|
          yield(service_file, idx)
        end
      end

      def sidekiq_services
        services = []
        if fetch(:sidekiq_special_queues)
          fetch(:sidekiq_queued_processes, []).each do |qp|
            count = (qp[:processes] || 1).to_i
            count.times do |idx|
              services << "#{fetch(:sidekiq_service_file)}-#{qp[:queue]}-#{idx}"
            end
          end
        else
          count = fetch(:sidekiq_processes).to_i
          count.times do |idx|
            services << "#{fetch(:sidekiq_service_file)}-#{idx}"
          end
        end
        services
      end

      def sidekiq_special_config(idx)
        if fetch(:sidekiq_special_queues)
          settings = fetch(:sidekiq_queued_processes).map do |queue_config|
            count = (queue_config[:processes] || 1).to_i
            count.times.map do
              {
                queue: queue_config[:queue] || "default",
                concurrency: queue_config[:worker] || 7
              }
            end
          end.flatten
          settings[idx.to_i]
        else
          {}
        end
      end

    end
  end
end
