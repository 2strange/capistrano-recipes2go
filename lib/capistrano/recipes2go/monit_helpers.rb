module Capistrano
  module MagicRecipes
    module MonitHelpers
      def monit_config(name, destination = nil, role = nil)
        @role = role
        destination ||= "/etc/monit/conf.d/#{name}.conf"
        template_with_role "monit/#{name}", "/tmp/monit_#{name}", @role
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

      
    end
  end
end
