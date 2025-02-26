require 'capistrano/recipes2go/sidekiq_helpers'
include Capistrano::Recipes2go::SidekiqHelpers

namespace :load do
  task :defaults do
    set :sidekiq_default_hooks,   -> { true }
    set :sidekiq_service_file,    -> { "sidekiq_#{fetch(:application)}_#{fetch(:stage)}" }
    set :sidekiq_timeout,         -> { 10 }
    set :sidekiq_roles,           -> { :app }
    set :sidekiq_processes,       -> { 1 }

    set :sidekiq_special_queues,  -> { false }
    set :sidekiq_queued_processes,-> { [] }

    set :sidekiq_service_path,    -> { "/lib/systemd/system" }
    set :sidekiq_pid_path,        -> { "/home/#{fetch(:user)}/run" }
    set :sidekiq_template,        -> { :default }

    set :sidekiq_ruby_vm,         -> { :rvm }   # ( :rvm | :rbenv | :system )
    set :sidekiq_user,            -> { fetch(:user, 'deploy') }
    set :sidekiq_log_lines,       -> { 100 }
  end
end

namespace :sidekiq do

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
    args.push fetch(:sidekiq_options) if fetch(:sidekiq_options)

    @service_file   = service_file
    @sidekiq_args   = args.compact.join(' ')

    template_file = fetch(:sidekiq_template, :default) == :default ? "sidekiq.service" : fetch(:sidekiq_template)

    template2go(template_file, '/tmp/sidekiq.service')
    execute :sudo, :mv, '/tmp/sidekiq.service', "#{fetch(:sidekiq_service_path)}/#{service_file}.service"
  end

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
