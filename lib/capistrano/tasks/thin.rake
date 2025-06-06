require 'capistrano/recipes2go/base_helpers'
include Capistrano::Recipes2go::BaseHelpers

namespace :load do
  task :defaults do
    
    set :thin_path,                   -> { '/etc/thin' }
    set :thin_roles,                  -> { :web }
    
    set :thin_timeout,                -> { 42 }
    set :thin_max_conns,              -> { 1024 }
    set :thin_max_persistent_conns,   -> { 512 }
    set :thin_require,                -> { [] }
    set :thin_wait,                   -> { 90 }
    set :thin_onebyone,               -> { true }

    set :thin_servers,                -> { fetch(:app_instances, 1) }
    
    set :thin_daemonize,              -> { false } # Thin should not daemonize itself
    set :thin_hooks,                  -> { true }  # Enables automatic setup/restart

    set :thin_daemon_ruby_vm,         -> { :rvm }   # ( :rvm | :rbenv | :system )
    set :thin_daemon_file,            -> { "#{fetch(:application)}_#{fetch(:stage)}_thin" }

    set :thin_daemon_old,             -> { "thin_#{fetch(:application)}_#{fetch(:stage)}" }

    set :thin_daemon_path,            -> { "/lib/systemd/system" }
    set :thin_pid_path,               -> { "#{shared_path}/pids" }
    set :thin_daemon_template,        -> { :default }
    set :thin_daemon_log_lines,       -> { 100 }
    set :thin_daemon_user,            -> { fetch(:user, 'deploy') }  # Defaults to deploy user


    ## symlink thin config file
    append :linked_files, "config/thin_app_#{ fetch(:stage) }.yml"

  end
end


namespace :thin do
  
  def upload_thin_daemon
    puts "📤 Uploading Thin systemd service..."
    if fetch(:thin_daemon_template, :default) == :default
      template2go("thin_service", '/tmp/thin_service')
    else
      template2go(fetch(:thin_daemon_template), '/tmp/thin_service')
    end
    execute :sudo, :mv, '/tmp/thin_service', "#{fetch(:thin_daemon_path)}/#{fetch(:thin_daemon_file)}.service"
    execute :sudo, "systemctl daemon-reload"
  end

  def upload_thin_config
    puts "📤 Uploading Thin configuration..."
    template2go("thin_config", '/tmp/thin_app.yml')
    # Speichern im shared_path (Capistrano erwartet das so!)
    execute :sudo, :mv, '/tmp/thin_app.yml', "#{shared_path}/config/thin_app_#{fetch(:stage)}.yml"
  end

  ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 

  desc 'Upload only the Thin daemon file'
  task :upload_daemon  do
    on roles fetch(:thin_roles) do
      upload_thin_daemon
    end
  end

  desc "Upload only the Thin config file"
  task :reconf do
    on release_roles fetch(:thin_roles) do
      upload_thin_config
    end
  end

  desc "Initial Thin Setup (Upload service & config, but don't enable yet)"
  task :setup do
    on roles fetch(:thin_roles) do
      upload_thin_daemon
      upload_thin_config
      puts "✅ Thin setup completed. Service is NOT yet enabled or started."
    end
  end

  desc "Activate and start Thin service"
  task :activate do
    on roles fetch(:thin_roles) do
      invoke "thin:enable"
      invoke "thin:start"
      puts "✅ Thin service activated and running!"
    end
  end
  
  %w[start stop restart enable disable is-enabled].each do |cmnd|
    desc "#{cmnd.capitalize} Thin service"
    task cmnd.gsub(/-/, '_') do
      on roles fetch(:thin_roles) do
        execute :sudo, :systemctl, cmnd, fetch(:thin_daemon_file)
      end
    end
  end
  
  desc "Quiet Thin service (TSTP signal)"
  task :quiet do
    on roles fetch(:thin_roles) do
      execute :sudo, :systemctl, 'kill -s TSTP', fetch(:thin_daemon_file)
    end
  end
  
  desc "Get logs for Thin service"
  task :logs do
    on roles fetch(:thin_roles) do
      execute :sudo, :journalctl, '-u', fetch(:thin_daemon_file), '-rn', fetch(:thin_daemon_log_lines, 100)
    end
  end
  
  desc "Check Thin service status"
  task :check_status do
    on roles fetch(:thin_roles) do
      within current_path do
        puts "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
        puts "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
        puts fetch(:thin_daemon_file)
        puts "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
        output = capture :sudo, "systemctl status", fetch(:thin_daemon_file)
        output.each_line do |line|
            puts line
        end
        puts "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
      end
    end
  end


  desc "Remove old style Thin service files (thin_APP_NAME)"
  task :remove_old_services do
    on roles fetch(:thin_roles) do
      old_service_file = fetch( :thin_daemon_old, "thin_#{fetch(:application)}_#{fetch(:stage)}" )
      
      if test("[ -f #{fetch(:thin_daemon_path)}/#{old_service_file}.service ]")
        unless test("systemctl is-enabled #{old_service_file} || echo disabled") == "disabled"
          info "🔧 Disabling #{old_service_file} service..."
          execute :sudo, "systemctl disable #{old_service_file}"
        else
          info "✅ #{old_service_file} is already disabled, skipping."
        end
        puts "🔄 Stopping old Thin service: #{old_service_file}.service"
        execute :sudo, "systemctl stop #{old_service_file}"
        puts "🗑 Removing old Thin service file: #{old_service_file}.service"
        execute :sudo, :rm, "-f", "#{fetch(:thin_daemon_path)}/#{old_service_file}.service"
      else
        puts "⚠️  Old Thin service file #{old_service_file}.service does not exist, skipping removal."
      end
    end
  end
  
end



namespace :deploy do
  after 'deploy:published', :restart_thin_apps do
    if fetch(:thin_hooks)
      invoke "thin:reconf"
      invoke "thin:restart"
    end
  end
end


### Add Thin setup to the main setup task
task :setup do
  invoke "thin:setup"
end
