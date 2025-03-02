require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/sidekiq_helpers'
include Capistrano::Recipes2go::BaseHelpers
include Capistrano::Recipes2go::SidekiqHelpers

namespace :load do
  task :defaults do
    set :sidekiq_default_hooks,   -> { true }
    set :sidekiq_service_file,    -> { "#{fetch(:application)}_#{fetch(:stage)}_sidekiq" }
    set :sidekiq_timeout,         -> { 10 }
    set :sidekiq_roles,           -> { :app }
    set :sidekiq_processes,       -> { 1 }

    set :sidekiq_special_queues,  -> { false }
    set :sidekiq_queued_processes,-> { [] }

    set :sidekiq_service_path,    -> { "/lib/systemd/system" }
    set :sidekiq_pid_path,        -> { "#{shared_path}/pids" }
    set :sidekiq_log_path,        -> { "#{shared_path}/log" }
    set :sidekiq_template,        -> { :default }

    set :sidekiq_ruby_vm,         -> { :rvm }   # ( :rvm | :rbenv | :system )
    set :sidekiq_user,            -> { fetch(:user, 'deploy') }
    set :sidekiq_log_lines,       -> { 100 }
  end
end

namespace :sidekiq do

  desc "Upload Sidekiq systemd service files"
  task :upload_services do
    on roles fetch(:sidekiq_roles) do
      for_each_process do |service_file, idx|
        upload_service(service_file, idx)
      end
      execute :sudo, "systemctl daemon-reload"
    end
  end

  %w[start stop restart enable disable is-enabled].each do |cmd|
    desc "#{cmd.capitalize} Sidekiq service"
    task cmd.gsub(/-/, '_') do
      on roles fetch(:sidekiq_roles) do
        for_each_process do |service_file, _|
          execute :sudo, :systemctl, cmd, service_file
        end
      end
    end
  end

  desc "Quiet Sidekiq service"
  task :quiet do
    on roles fetch(:sidekiq_roles) do
      for_each_process do |service_file, _|
        execute :sudo, :systemctl, 'kill -s TSTP', service_file
      end
    end
  end

  desc "Get logs for Sidekiq service"
  task :logs do
    on roles fetch(:sidekiq_roles) do
      for_each_process do |service_file, _|
        execute :sudo, :journalctl, '-u', service_file, '-rn', fetch(:sidekiq_log_lines, 100)
      end
    end
  end

  desc "Check Sidekiq service status"
  task :check_status do
    on roles fetch(:sidekiq_roles) do
      for_each_process do |service_file, _|
        puts "🔍 Checking status of: #{service_file}"
        output = capture :sudo, "systemctl status #{service_file}"
        puts output
      end
    end
  end

  desc "Setup Sidekiq (Upload services, but do NOT start)"
  task :setup do
    on roles fetch(:sidekiq_roles) do
      invoke "sidekiq:upload_services"
      puts "✅ Sidekiq setup completed! Services are NOT started."
    end
  end

  desc "Deploy Sidekiq (Upload & Start)"
  task :deploy do
    on roles fetch(:sidekiq_roles) do
      invoke "sidekiq:setup"
      invoke "sidekiq:enable"
      invoke "sidekiq:start"
      puts "✅ Sidekiq services deployed and running!"
    end
  end
end

namespace :deploy do
  before :starting, :stop_sidekiq_services do
    if fetch(:sidekiq_default_hooks)
      invoke "sidekiq:stop"
    end
  end
  after :finished, :restart_sidekiq_services do
    if fetch(:sidekiq_default_hooks)
      invoke "sidekiq:start"
    end
  end
end
