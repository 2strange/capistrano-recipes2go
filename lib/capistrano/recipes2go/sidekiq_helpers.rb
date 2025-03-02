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
              service_name = "#{fetch(:sidekiq_service_file)}-#{qp[:queue]}"
              service_name += "-#{idx}" if count > 1
              services << service_name
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


      def upload_service(service_file, idx = 0)
        args = []
        args.push "--environment #{fetch(:stage)}"
        args.push "--require #{fetch(:sidekiq_require)}" if fetch(:sidekiq_require)
        args.push "--tag #{fetch(:sidekiq_tag)}" if fetch(:sidekiq_tag)

        if fetch(:sidekiq_special_queues)
          queue_config = sidekiq_special_config(idx)
          args.push "--queue #{queue_config[:queue] || 'default'}"
          args.push "--concurrency #{queue_config[:concurrency] || 7}"
        else
          Array(fetch(:sidekiq_queue)).each do |queue|
            args.push "--queue #{queue}"
          end
          args.push "--concurrency #{fetch(:sidekiq_concurrency)}" if fetch(:sidekiq_concurrency)
        end

        args.push "--config #{fetch(:sidekiq_config)}" if fetch(:sidekiq_config)
        
        # args.push "--logfile #{fetch(:sidekiq_log_path)}/#{service_file}.log"
        args.push "--logfile #{fetch(:sidekiq_log_path)}/sidekiq.log"
        
        args.push fetch(:sidekiq_options) if fetch(:sidekiq_options)

        @service_file   = service_file
        @sidekiq_args   = args.compact.join(' ')

        template_file = fetch(:sidekiq_template, :default) == :default ? "sidekiq_service" : fetch(:sidekiq_template)

        template2go(template_file, '/tmp/sidekiq.service')
        execute :sudo, :mv, '/tmp/sidekiq.service', "#{fetch(:sidekiq_service_path)}/#{service_file}.service"
      end

    end
  end
end
