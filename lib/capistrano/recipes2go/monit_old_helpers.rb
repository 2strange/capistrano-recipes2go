module Capistrano
  module Recipes2go
    module MonitHelpers
      def monit_config(name, destination = nil, role = nil)
        @role = role
        destination ||= "/etc/monit/conf.d/#{name}.conf"
        template2go "monit/#{name}", "/tmp/monit_#{name}", @role
        execute :sudo, "mv /tmp/monit_#{name} #{destination}"
        execute :sudo, "chown root #{destination}"
        execute :sudo, "chmod 600 #{destination}"
      end

      def monit_role_prefix(role)
        case role.to_s.downcase.strip
        when "sh", "shell"
          "/bin/sh -c 'REAL_COMMAND_HERE'"
        when "bash"
          "/bin/bash -c 'REAL_COMMAND_HERE'"
        else
          "/bin/su - #{fetch(:user)} -c 'REAL_COMMAND_HERE'"
        end
      end

      def monit_app_prefixed(cmd)
        komando = monit_role_prefix(fetch(:monit_app_worker_role, :user))

        case fetch(:monit_app_worker_prefix, :env).to_s.downcase.strip
        when "rvm"
          komando.gsub!(/REAL_COMMAND_HERE/, "cd #{current_path} ; #{fetch(:rvm_path)}/bin/rvm #{fetch(:rvm_ruby_version)} do bundle exec MONIT_CMD")
        when "rvm1capistrano3", "rvm1capistrano", "rvm1"
          komando.gsub!(/REAL_COMMAND_HERE/, "cd #{current_path} ; #{fetch(:rvm1_auto_script_path)}/rvm-auto.sh #{fetch(:rvm1_ruby_version)} bundle exec MONIT_CMD")
        else
          komando.gsub!(/REAL_COMMAND_HERE/, "/usr/bin/env cd #{current_path} ; bundle exec MONIT_CMD")
        end

        komando.gsub(/MONIT_CMD/, cmd)
      end

      def monit_pm2_prefixed(cmd)
        komando = monit_role_prefix(fetch(:monit_pm2_worker_role, :user))
        komando.gsub!(/REAL_COMMAND_HERE/, "cd #{fetch(:monit_pm2_app_path)} ; #{fetch(:monit_pm2_worker_prefix, '')} MONIT_CMD")
        komando.gsub(/MONIT_CMD/, cmd)
      end

      def init_site_check_item(domain)
        {
          ssl: false,
          check_content: false,
          path: '/',
          content: '<!DOCTYPE html>',
          timeout: 30,
          cycles: 3
        }.merge(domain).tap do |that|
          that[:name] = that[:domain] if [nil, '', ' '].include?(that[:name])
        end
      end

      def init_file_check_item(file)
        {
          name: '',
          path: '',
          max_size: 12,
          clear: false
        }.merge(file).tap do |that|
          that[:name] = that[:path].to_s.split('/').last if [nil, '', ' '].include?(that[:name])
        end
      end

      def monit_website_list
        Array(fetch(:monit_websites_to_check)).map { |x| init_site_check_item(x) }
      end

      def monit_files_list
        Array(fetch(:monit_files_to_check)).map { |x| init_file_check_item(x) }
      end

      def monit_alert
        if fetch(:monit_use_slack, false)
          "exec #{fetch(:monit_slack_bin_path)} and repeat every 3 cycles"
        else
          "alert"
        end
      end

      def sidekiq_six_service_name(service_file)
        "#{fetch(:application)}_#{fetch(:stage)}_sidekiq_#{service_file.split('-').last}"
      end




      ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###



      def monit_config(name, destination = nil, role = nil)
        @role = role
        destination ||= "/etc/monit/conf.d/#{name}.conf"
        template_with_role "monit/#{name}", "/tmp/monit_#{name}", @role
        
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




      def ensure_monit_installed
        execute :sudo, 'apt-get update'
        execute :sudo, 'apt-get -y install monit'
      end

      def detect_monit_processes
        # processes = %w[nginx postgresql redis]
        processes = []
        processes << "nginx" if test("which nginx")
        processes << "postgresql" if test("which psql")
        processes << "redis" if test("which redis-server")
        processes << 'sidekiq' if fetch(:sidekiq_enabled, false)
        processes << 'puma' if fetch(:puma_enabled, false)
        processes
      end

      def upload_monit_configs
        monit_config('monitrc', '/etc/monit/monitrc')
        fetch(:monit_processes).each do |process|
          monit_config(process, "/etc/monit/conf.d/#{process}.conf")
        end
        setup_monit_webclient if fetch(:monit_http_client, false)
      end

      def monit_config(name, destination)
        template2go("monit/#{name}", "/tmp/monit_#{name}")
        execute :sudo, "mv /tmp/monit_#{name} #{destination}"
        execute :sudo, "chown root #{destination}"
        execute :sudo, "chmod 600 #{destination}"
      end

      def setup_monit_webclient
        execute :sudo, "mkdir -p /etc/monit/conf.d"
        monit_config('monit_webclient', '/etc/monit/conf.d/monit_webclient.conf')
      end

      def restart_monitored_processes
        fetch(:monit_processes).each do |process|
          execute :sudo, "#{fetch(:monit_bin)} restart #{process}"
        end
      end

      def stop_monitored_processes
        fetch(:monit_processes).each do |process|
          execute :sudo, "#{fetch(:monit_bin)} stop #{process}"
        end
      end

      def setup_certbot_for_monit
        execute :sudo, "certbot --non-interactive --agree-tos --email #{fetch(:monit_mail_server)} certonly --webroot -w #{fetch(:deploy_to)}/shared -d #{fetch(:monit_webclient_domain)}"
      end


    end
  end
end
