require 'erb'
require 'stringio'

module Capistrano
  module Recipes2go
    module BaseHelpers
      
      def rvm_command(user = fetch(:user))
        ## Systemd requires absolute paths for RVM execution
        rvm_path = fetch(:rvm_custom_path, false) || "/home/#{user}/.rvm"
        "#{rvm_path}/bin/rvm #{fetch(:rvm_ruby_version)} do"
      end


      ## PAth helpers
      def ensure_shared_path(path)
        unless test("[ -d #{path} ]")
          puts "📂 Directory #{path} does not exist. Creating it..."
          execute :mkdir, "-p", path
        else
          puts "✅ Directory #{path} already exists."
        end
        ensure_shared_path_ownership
      end

      def ensure_shared_config_path
        ensure_shared_path("#{shared_path}/config")
      end

      def ensure_shared_pids_path
        ensure_shared_path("#{shared_path}/pids")
      end

      def ensure_shared_sockets_path
        ensure_shared_path("#{shared_path}/tmp/sockets")
      end

      def ensure_shared_path_ownership
        # Fix ownership only if needed (avoids unnecessary chown operations)
        unless test("stat -c '%U:%G' #{shared_path} | grep #{fetch(:user)}:#{fetch(:user)}")
          puts "🔧 Fixing ownership of #{shared_path} and its parent directories..."
          execute :sudo, :chown, "-R #{fetch(:user)}:#{fetch(:user)} #{shared_path}"
          execute :sudo, :chown, "#{fetch(:user)}:#{fetch(:user)} #{fetch(:deploy_to)}"
        else
          puts "✅ Ownership is already correct."
        end
      end



      def template2go(from, to, role = nil)
        @role = role  ## Set role for template (used in monit)
        erb = get_template_file(from)
        upload! StringIO.new( ERB.new(erb).result(binding) ), to
      end
      
      
      def render2go(tmpl)
        erb = get_template_file(tmpl)
        ERB.new(erb).result(binding)
      end
      
      
      def get_template_file( from )
        [
            File.join('config', 'deploy', 'templates', "#{from}.erb"),
            File.join('config', 'deploy', 'templates', "#{from}"),
            File.join('lib', 'capistrano', 'templates', "#{from}.erb"),
            File.join('lib', 'capistrano', 'templates', "#{from}"),
            File.expand_path("../../../generators/capistrano/recipes2go/templates/#{from}.erb", __FILE__),
            File.expand_path("../../../generators/capistrano/recipes2go/templates/#{from}", __FILE__)
        ].each do |path|
          return File.read(path) if File.file?(path)
        end
        # false
        raise "File '#{from}' was not found!!!"
      end


      def puma_command
        fetch(:puma_ruby_vm) == :rvm ? "#{rvm_command(fetch(:puma_user))} bundle exec puma" : "/usr/local/bin/bundle exec puma"
      end


      def ruby_command
        fetch(:puma_ruby_vm) == :rvm ? "#{rvm_command(fetch(:user))} bundle exec ruby" : "/usr/local/bin/bundle exec ruby"
      end



      def remove_app_service( name = "SERVICE", serivce_path = "/lib/systemd/system", service_file = nil )
        if test("[ -f #{serivce_path}/#{service_file}.service ]")
          unless test("systemctl is-enabled #{service_file} || echo disabled") == "disabled"
            info "🔧 Disabling #{service_file} service..."
            execute :sudo, "systemctl disable #{service_file}"
          else
            info "✅ #{service_file} is already disabled, skipping."
          end
          puts "🔄 Stopping old #{name} service: #{service_file}.service"
          execute :sudo, "systemctl stop #{service_file}"
          puts "🗑 Removing old #{name} service file: #{service_file}.service"
          execute :sudo, :rm, "-f", "#{serivce_path}/#{service_file}.service"
        else
          puts "⚠️  Old #{name} service file #{service_file}.service does not exist, skipping removal."
        end
      end
      
      
    end
  end
end




