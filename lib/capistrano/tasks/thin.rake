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
    # https://help.cloud66.com/rails/how-to-guides/rack-servers/thin-rack-server.html
    # You should not daemonize the custom_web process !!!
    set :thin_daemonize,              -> { false }
    set :thin_hooks,                  -> { true }
    
    set :thin_daemon_ruby_vm,         -> { :rvm }   # ( :rvm | :rbenv | :system )
    set :thin_daemon_file,            -> { "thin_#{fetch(:application)}_#{fetch(:stage)}" }
    set :thin_daemon_path,            -> { "/lib/systemd/system" }
    set :thin_pid_path,               -> { "#{shared_path}/pids" }
    set :thin_daemon_template,        -> { :default }
    set :thin_daemon_log_lines,       -> { 100 }
    set :thin_daemon_user,            -> { fetch(:user, 'deploy') }  # role-user
    
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
    execute :sudo, :mv, '/tmp/thin_app.yml', "#{shared_path}/config/thin_app_#{fetch(:stage)}.yml"
    execute :sudo, :ln, '-sf', "#{shared_path}/config/thin_app_#{fetch(:stage)}.yml", "#{fetch(:thin_path)}/thin_#{fetch(:application)}_#{fetch(:stage)}.yml"
  end

  def rvm_command
    ## systemd needs absolute paths!
    "/home/#{ fetch(:thin_daemon_user) }/.rvm/bin/rvm #{fetch(:rvm_ruby_version)} do"
  end
  
  
  ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 
  ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 
  
  
  desc 'Upload only the Thin daemon file'
  task :upload_daemon  do
    on roles fetch(:thin_roles) do
      within current_path do
        upload_thin_daemon
      end
    end
  end

  desc "Upload only the Thin config file"
  task :reconf do
    on release_roles fetch(:thin_roles) do
      within current_path do
        upload_thin_config
      end
    end
  end


  desc "Setup Thin: Upload service, config, and enable"
  task :setup do
    on roles fetch(:thin_roles) do
      within current_path do
        upload_thin_daemon
        upload_thin_config
        invoke "thin:enable"
        invoke "thin:start"
        puts "✅ Thin service setup completed!"
      end
    end
  end
  
  
  
  %w[start stop restart enable disable is-enabled].each do |cmnd|
    desc "#{cmnd.capitalize} Thin service"
    task cmnd.gsub(/-/, '_') do
      on roles fetch(:thin_roles) do
        within current_path do
          execute :sudo, :systemctl, cmnd, fetch(:thin_daemon_file)
        end
      end
    end
  end
  
  desc "Quiet Thin service"
  task :quiet do
    on roles fetch(:thin_roles) do
      within current_path do
        execute :sudo, :systemctl, 'kill -s TSTP', fetch(:thin_daemon_file)
      end
    end
  end
  
  desc "Get logs for Thin service"
  task :logs do
    on roles fetch(:thin_roles) do
      within current_path do
        execute :sudo, :journalctl, '-u', fetch(:thin_daemon_file), '-rn', fetch(:thin_daemon_log_lines, 100)
      end
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
  
  
end




namespace :deploy do
  after 'deploy:published', :restart_thin_apps do
    if fetch(:thin_hooks)
      invoke "thin:reconf"
      invoke "thin:restart"
    end
  end
end

