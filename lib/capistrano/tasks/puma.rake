require 'capistrano/recipes2go/base_helpers'
include Capistrano::Recipes2go::BaseHelpers

namespace :load do
  task :defaults do
    set :puma_roles,              -> { :app }
    set :puma_service_file,       -> { "puma_#{fetch(:application)}_#{fetch(:stage)}" }
    set :puma_systemd_path,       -> { "/etc/systemd/system" }
    set :puma_pid_path,           -> { "#{shared_path}/pids" }
    set :puma_socket_path,        -> { "#{shared_path}/tmp/sockets" }
    set :puma_state,              -> { "#{shared_path}/puma.state" }
    set :puma_log_path,           -> { "#{shared_path}/log/puma.log" }

    ## Puma Performance Configuration
    set :puma_workers,            -> { fetch(:app_instances, 1) } # Number of workers
    set :puma_threads,            -> { [4, 8] } # (min, max) threads per worker
    ## Example decision:
    # => Small app (low traffic) ➝ 1 worker, 4-8 threads.
    # => Medium app ➝ 2 workers, 8-16 threads.
    # => Large app (high traffic) ➝ 4+ workers, 16+ threads.
    

    set :puma_preload_app,        -> { true }
    set :puma_min_threads,        -> { fetch(:puma_threads).first }
    set :puma_max_threads,        -> { fetch(:puma_threads).last }
    set :puma_hooks,              -> { true }
    set :puma_ruby_vm,            -> { :rvm }   # ( :rvm | :rbenv | :system )
    set :puma_user,               -> { fetch(:user, 'deploy') }  # Standardmäßiger Benutzer
    set :puma_log_lines,          -> { 100 }

    set :puma_semantic_logger,    -> { true }

    ## symlink puma config file
    append :linked_files, "config/puma.rb"
    append :linked_dirs, "log", "pids", "tmp/sockets"

  end
end

namespace :puma do

  def upload_puma_service
    puts "📤 Uploading Puma systemd service..."
    template2go("puma_service", "/tmp/puma.service")

    # Ensure the config and pids folders exist
    ensure_shared_config_path
    ensure_shared_pids_path
    ensure_shared_sockets_path

    execute :sudo, :mv, "/tmp/puma.service", "#{fetch(:puma_systemd_path)}/#{fetch(:puma_service_file)}.service"
    execute :sudo, "systemctl daemon-reload"
  end

  def upload_puma_config
    puts "📤 Uploading Puma configuration..."
    template2go("puma_config", "/tmp/puma.rb")
    
    # Ensure the config and pids folders exist
    ensure_shared_config_path
    ensure_shared_pids_path
    ensure_shared_sockets_path

    execute :sudo, :mv, "/tmp/puma.rb", "#{shared_path}/config/puma.rb"
  end

  desc 'Upload only the Puma systemd service file'
  task :upload_service do
    on roles fetch(:puma_roles) do
      upload_puma_service
    end
  end

  desc "Upload only the Puma config file"
  task :upload_config do
    on roles fetch(:puma_roles) do
      upload_puma_config
    end
  end

  desc "Setup Puma: Upload service & config (but don't enable yet)"
  task :setup do
    on roles fetch(:puma_roles) do
      upload_puma_service
      upload_puma_config
      puts "✅ Puma setup completed. Service is NOT yet enabled or started."
    end
  end

  desc "Activate and start Puma service"
  task :activate do
    on roles fetch(:puma_roles) do
      ensure_shared_pids_path
      ensure_shared_sockets_path
      invoke "puma:enable"
      invoke "puma:start"
      puts "✅ Puma service activated and running!"
    end
  end

  %w[start stop restart enable disable is-enabled].each do |command|
    desc "#{command.capitalize} Puma service"
    task command.gsub(/-/, '_') do
      on roles fetch(:puma_roles) do
        if %w[start restart enable].include?(command)
          # Ensure pids directory exists only for start, restart, or enable
          ensure_shared_pids_path 
          # 🔥 Ensure the socket directory exists!
          ensure_shared_sockets_path
        end

        execute :sudo, :systemctl, command, fetch(:puma_service_file)
      end
    end
  end

  desc "Enable Puma service if it's not already enabled"
  task :enable_if_needed do
    on roles(:app) do
      # Check if the service is already enabled
      if test("systemctl is-enabled #{fetch(:puma_service_file)} || echo disabled") == "disabled"
        info "🔧 Enabling #{fetch(:puma_service_file)} service..."
        execute :sudo, "systemctl enable --now #{fetch(:puma_service_file)}"
      else
        info "✅ #{fetch(:puma_service_file)} is already enabled, skipping."
      end
    end
  end

  desc "Check Puma service status"
  task :check_status do
    on roles fetch(:puma_roles) do
      execute :sudo, "systemctl status #{fetch(:puma_service_file)} --no-pager"
    end
  end

  desc "Get logs for Puma service"
  task :logs do
    on roles fetch(:puma_roles) do
      execute :sudo, "journalctl -u #{fetch(:puma_service_file)} -rn #{fetch(:puma_log_lines, 100)}"
    end
  end
end

namespace :deploy do
  after 'deploy:published', :restart_puma do
    if fetch(:puma_hooks)
      invoke "puma:upload_config"
      invoke "puma:enable_if_needed"
      invoke "puma:restart"
    end
  end
end

### Add Puma setup to the main setup task
task :setup do
  invoke "puma:setup"
end
