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
        processes += Array(fetch(:monit_system_processes, []))
        processes += Array(fetch(:monit_app_processes, []))
        processes << "websites"   if Array(fetch(:monit_websites_to_check, [])).any? && !processes.include?("websites")
        processes << "hosts"      if Array(fetch(:monit_hosts_to_check, [])).any? && !processes.include?("hosts")
        processes << "files"      if Array(fetch(:monit_files_to_check, [])).any? && !processes.include?("files")
        # processes << "folders"    if Array(fetch(:monit_folders_to_check, [])).any? && !processes.include?("folders")
        processes
      end


      ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###
      # Monit Configs

      def monit_config(name, destination = nil, role = nil)
        destination ||= "/etc/monit/conf.d/#{ monit_process_name(name) }.conf" if name != "monitrc"
        destination ||= "/etc/monit/monitrc"
        template2go "monit/#{name}", "/tmp/monit_#{name}", role
        
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
          name += "_#{idx}" if !!idx
          name
        end
      end


      def monit_process_command(process, command)
        if process == "pm2"
          fetch(:monit_pm2_app_instances, 0).times do |idx|
            execute :sudo, "#{fetch(:monit_bin)} #{command} #{ monit_app_process_name('pm2', idx) }"
          end
        else
          execute :sudo, "#{fetch(:monit_bin)} #{command} #{monit_process_name(process)}"
        end
      end



      def sidekiq_service_name(service_file, idx = nil)
        "#{fetch(:application)}_#{fetch(:stage)}_sidekiq_#{ service_file.split('-').last }"
      end



      # Monit alert command
      def monit_alert(cycles = 15)
        ## Doesnt work with multiple commands
        # cmds = []
        # if fetch(:monit_event_api_url, false)
        #   cmds << "exec #{fetch(:monit_event_api_bin_path)} and repeat every 3 cycles"
        # end
        # if fetch(:monit_use_slack, false)
        #   cmds << "exec #{fetch(:monit_slack_bin_path)} and repeat every #{cycles} cycles"
        # end
        # cmds << "alert" if cmds.empty?
        # cmds.join("\n")
        if fetch(:monit_event_api_url, false)
          # If event API is enabled, use event API alert command
          "exec #{fetch(:monit_event_api_bin_path)} and repeat every 3 cycles"
        elsif fetch(:monit_use_slack, false)
          # If slack is enabled, use slack alert command
          "exec #{fetch(:monit_slack_bin_path)} and repeat every #{cycles} cycles"
        else
          # Default alert command
          "alert"
        end
      end



      def init_site_check_item( domain )
        ## defaults
        that = { ssl: false, check_content: false, path: '/', content: '<!DOCTYPE html>', timeout: 30, cycles: 3 }
        that.merge! domain
        that[:name] = that[:domain]   if [nil, '', ' '].include?( that[:name] )
        that
      end

      def init_file_check_item( file )
        ## defaults
        that = { name: '', path: '', max_size: 12, clear: false }
        that.merge! file
        that[:name] = that[:path].to_s.split('/').last   if [nil, '', ' '].include?( that[:name] )
        that
      end


      def init_folder_check_item( file )
        ## defaults
        that = { name: '', path: '', max_size: 20 }
        that.merge! file
        that[:name] = that[:path].to_s.split('/').last   if [nil, '', ' '].include?( that[:name] )
        that
      end

      def init_host_check_item( file )
        ## defaults
        that = { name: '', host: 'localhost', port: 80, protocol: 'http', cycles: 3 }
        that.merge! file
        that[:name] = that[:host].to_s   if [nil, '', ' '].include?( that[:name] )
        that
      end

      def monit_website_list
        Array( fetch(:monit_websites_to_check) ).map{ |x| init_site_check_item(x) }
      end

      def monit_files_list
        Array( fetch(:monit_files_to_check) ).map{ |x| init_file_check_item(x) }
      end

      def monit_folders_list
        Array( fetch(:monit_folders_to_check) ).map{ |x| init_folder_check_item(x) }
      end

      def monit_hosts_list
        Array( fetch(:monit_hosts_to_check) ).map{ |x| init_host_check_item(x) }
      end



    end
  end
end
