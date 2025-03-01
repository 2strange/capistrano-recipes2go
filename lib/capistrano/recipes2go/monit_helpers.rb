module Capistrano
  module Recipes2go
    module MonitHelpers
      
      def ensure_monit_installed
        unless test("which monit")
          info "📦 Installing Monit..."
          execute :sudo, 'apt-get update'
          execute :sudo, 'apt-get -y install monit'
        else
          info "✅ Monit is already installed."
        end
      end

      def detect_monit_system_processes
        # processes = %w[nginx postgresql redis]
        processes = []
        processes << "nginx" if test("which nginx")
        processes << "postgresql" if test("which psql")
        processes << "redis" if test("which redis-server")
        processes
      end

      # All processes
      def monit_processes
        processes = []
        processes + Array(fetch(:monit_system_processes, []))
        processes + Array(fetch(:monit_app_processes, []))
        processes << "websites" if Array(fetch(:monit_websites_to_check, [])).any?
        processes << "files" if Array(fetch(:monit_files_to_check, [])).any?
        processes
      end


      ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###
      # Monit Configs

      def monit_config(name, destination = nil, role = nil)
        destination ||= "/etc/monit/conf.d/#{ monit_process_name(name) }.conf" if name != "monitrc"
        destination ||= "/etc/monit/monitrc"
        template_with_role "monit/#{name}", "/tmp/monit_#{name}", role
        
        # Check if file has changed
        remote_checksum = capture(:md5sum, destination).split.first rescue nil
        local_checksum = capture(:md5sum, "/tmp/monit_#{name}").split.first
        
        if remote_checksum != local_checksum
          execute :sudo, "mv /tmp/monit_#{name} #{destination}"
          execute :sudo, "chown root #{destination}"
          execute :sudo, "chmod 600 #{destination}"
        else
          info "⚡ Monit config for #{name} is up-to-date, skipping upload."
          execute :sudo, "rm -f /tmp/monit_#{name}"
        end
      end


      ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###

      def monit_system_process_name(process)
        "#{process}"
      end

      def monit_app_process_name(process)
        "#{fetch(:application)}_#{fetch(:stage)}_#{process}"
      end

      def monit_process_name(process, idx = nil)
        if fetch(:monit_system_processes).include?(process)
          monit_system_process_name(process)
        else
          name = monit_app_process_name(process)
          name += "_#{idx}" if idx.present?
          name
        end
      end


      def monit_process_command(process, command)
        case process
        when "sidekiq"
          for_each_process do |service_file, idx|
            execute :sudo, "#{fetch(:monit_bin)} #{command} #{sidekiq_service_name(service_file, idx)}"
          end
        when "puma"
          if fetch(:puma_workers, 1) > 1 
            fetch(:puma_workers).times do |idx|
              execute :sudo, "#{fetch(:monit_bin)} #{command} #{monit_app_process_name('puma', idx)}"
            end
          else
            execute :sudo, "#{fetch(:monit_bin)} #{command} #{monit_app_process_name('puma')}"
          end
        when "thin"
          fetch(:app_instances).times do |idx|
            execute :sudo, "#{fetch(:monit_bin)} #{command} #{ monit_app_process_name('thin', idx) }"
          end
        when "pm2"
          fetch(:monit_pm2_app_instances, 0).times do |idx|
            execute :sudo, "#{fetch(:monit_bin)} #{command} #{ monit_app_process_name('pm2', idx) }"
          end
        else
          execute :sudo, "#{fetch(:monit_bin)} #{command} #{process}"
        end
      end



      def sidekiq_service_name(service_file, idx = nil)
        "#{fetch(:application)}_#{fetch(:stage)}_sidekiq_#{ service_file.split('-').last }"
      end

    end
  end
end
