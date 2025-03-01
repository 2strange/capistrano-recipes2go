require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/sidekiq_helpers'
require 'capistrano/recipes2go/monit_helpers'
include Capistrano::Recipes2go::MonitHelpers
include Capistrano::Recipes2go::SidekiqHelpers
include Capistrano::Recipes2go::BaseHelpers

namespace :load do
  task :defaults do
    set :monit_roles, -> { :web }
    set :monit_bin, -> { '/usr/bin/monit' }
    set :monit_logfile, -> { "#{shared_path}/log/monit.log" }
    set :monit_processes, -> { detect_monit_processes }
    set :monit_http_client, -> { true }
    set :monit_http_port, -> { 2812 }
    set :monit_mail_server, -> { 'smtp.gmail.com' }
    set :monit_mail_port, -> { 587 }
    set :monit_mail_authentication, -> { false }
    set :monit_webclient, -> { true }
    set :monit_webclient_domain, -> { "monitor.#{fetch(:application)}.#{fetch(:stage)}" }
    set :monit_letsencrypt_cert, -> { "/etc/letsencrypt/live/#{fetch(:monit_webclient_domain)}/fullchain.pem" }
    set :monit_letsencrypt_key, -> { "/etc/letsencrypt/live/#{fetch(:monit_webclient_domain)}/privkey.pem" }
  end
end

namespace :monit do
  task :install do
    on release_roles fetch(:monit_roles) do
      ensure_monit_installed
    end
  end

  task :setup do
    on release_roles fetch(:monit_roles) do
      upload_monit_configs
      invoke 'monit:configure_nginx'
      invoke 'monit:configure_certbot'
      invoke 'monit:syntax'
      invoke 'monit:reload'
    end
  end

  task :configure_nginx do
    on release_roles fetch(:monit_roles) do
      upload_monit_nginx_config
      execute :sudo, 'systemctl reload nginx'
    end
  end

  task :configure_certbot do
    on release_roles fetch(:monit_roles) do
      execute :sudo, "certbot --nginx --non-interactive --agree-tos --email #{fetch(:monit_mail_to)} -d #{fetch(:monit_webclient_domain)}"
    end
  end

  %w[start stop restart syntax reload].each do |command|
    task command do
      on release_roles fetch(:monit_roles) do
        execute :sudo, :service, :monit, command
      end
    end
  end

  task :restart_monitoring do
    on release_roles fetch(:monit_roles) do
      restart_monitored_processes
    end
  end
end

namespace :deploy do
  before :starting, :stop_monitoring do
    stop_monitored_processes
  end

  after :finished, :restart_monitoring do
    invoke 'monit:restart_monitoring'
  end
end

task :setup do
  invoke 'monit:setup'
end
