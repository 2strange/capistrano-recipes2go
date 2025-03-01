require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/monit_helpers'
require 'capistrano/recipes2go/sidekiq_helpers'
include Capistrano::Recipes2go::BaseHelpers
include Capistrano::Recipes2go::MonitHelpers
include Capistrano::Recipes2go::SidekiqHelpers


namespace :load do
  task :defaults do

    # Basis-Einstellungen für Monit
    set :monit_roles,                 -> { :web }
    set :monit_interval,              -> { 60 }
    set :monit_bin,                   -> { '/usr/bin/monit' }

    set :monit_logfile,               -> { "#{shared_path}/log/monit.log" }  # Default in Monit: /var/log/monit.log
    set :monit_idfile,                -> { '/var/lib/monit/id' }
    set :monit_statefile,             -> { '/var/lib/monit/state' }

    set :monit_eventqueue_dir,        -> { "#{ shared_path }/monit-events" }
    set :monit_eventqueue_slots,      -> { 300 }


    # Status und RC-Datei: Nur eine Seite soll das RC schreiben, wenn mehrere auf einem Server Monit nutzen
    set :monit_active,                -> { true }
    set :monit_main_rc,               -> { true }

    # Definierte Prozesse. Diese werden in den Monit-Configurationsdateien genutzt
    # set :monit_processes,             -> { %w[nginx postgresql thin website sidekiq redis pwa] }
    set :monit_system_processes,      -> { %w[nginx postgresql redis] }  # or: detect_monit_system_processes() = auto-detect [nginx, postgresql, redis]
    set :monit_app_processes,         -> { %w[puma] }  # puma, thin, sidekiq, etc.

    # Hauptname in den RC-Dateien (wird im Cockpit verwendet, wenn mehrere Monit-Instanzen vorliegen)
    set :monit_name,                  -> { "#{ fetch(:application) }_#{ fetch(:stage) }" }

    # Mailer-Block: Ermöglicht den Versand von Email-Warnungen
    set :monit_mail_server,           -> { "smtp.gmail.com" }
    set :monit_mail_port,             -> { 587 }
    set :monit_mail_authentication,   -> { false }  # Optionen: SSLAUTO|SSLV2|SSLV3|TLSV1|TLSV11|TLSV12
    set :monit_mail_username,         -> { "foo@example.com" }
    set :monit_mail_password,         -> { "secret" }
    set :monit_mail_to,               -> { "foo@example.com" }
    set :monit_mail_from,             -> { "monit@foo.bar" }
    set :monit_mail_reply_to,         -> { "support@foo.bar" }

    set :monit_ignore,                -> { [] }  # z. B. %w[action pid]

    # Zusätzliche Einstellungen für PostgreSQL
    set :monit_pg_pid,                -> { "/var/run/postgresql/12-main.pid" }

    # Einstellungen für Thin (benötigt secrets_key_base)
    set :monit_thin_totalmem_mb,      -> { 300 }
    set :monit_thin_pid_path,         -> { fetch(:thin_pid_path, "/home/#{fetch(:user)}/run") }
    set :thin_sysd_roles,             -> { fetch(:thin_roles) }

    # Einstellungen für Sidekiq (ehemals sidekiq_six, jetzt in "sidekiq" umbenannt)
    set :monit_sidekiq_totalmem_mb,   -> { 300 }
    set :monit_sidekiq_timeout_sec,   -> { 90 }
    set :monit_sidekiq_pid_path,      -> { fetch(:sidekiq_pid_path, "/home/#{fetch(:user)}/run") }  # Variable an Sidekiq angepasst

    # WebClient-Einstellungen: Erlaubt den externen Zugriff via nginx (mit optionaler SSL-Verschlüsselung)
    set :monit_http_port,             -> { 2812 }
    set :monit_http_username,         -> { "admin" }
    set :monit_http_password,         -> { "monitor" }
    set :monit_webclient,             -> { false }  # Domain für den Webclient
    set :monit_webclient_ssl,         -> { false }  # Nutzt SSL für den WebClient
    set :monit_webclient_ssl_cert,    -> { "/etc/letsencrypt/live/#{fetch(:monit_webclient)}/fullchain.pem" }
    set :monit_webclient_ssl_key,     -> { "/etc/letsencrypt/live/#{fetch(:monit_webclient)}/privkey.pem" }
    set :monit_nginx_template,        -> { :default }


    # Website-Monitoring: Statt der alten :monit_website_check_*-Variablen wird nun :monit_websites_to_check genutzt
    # Website: { name: String, domain: String, ssl: Boolean, check_content: Boolean, path: String, content: String, path: String, cycles: Integer, timeout: Integer }
    set :monit_websites_to_check,     -> { [] }


    # File-Monitoring: Überwacht Dateien (z. B. Log-Dateien)
    # FILE: { name: String, path: String, max_size: Integer, clear: Boolean }
    set :monit_files_to_check,        -> { [] }


    # URL für m/Monit API oder eigenen Service
    set :monit_mmonit_url,            -> { false }


    # Slack-Alerts: Sendet Benachrichtigungen via Slack API
    set :monit_use_slack,             -> { false }
    set :monit_slack_webhook,         -> { "" }  # Slack Webhook URL
    set :monit_slack_bin_path,        -> { "/etc/monit/alert_slack.sh" }

  end
end


namespace :monit do

  desc "Install Monit"
  task :install do
    on release_roles fetch(:monit_roles) do
      ensure_monit_installed
    end
  end

  desc "Setup Monit and upload configurations"
  task :setup do
    on roles fetch(:monit_roles) do
      # Monit-Configuration hochladen
      monit_config( "monitrc" )      if fetch(:monit_main_rc, false)
    end
    # Monit-Configurationsdateien für Prozesse hochladen
    monit_processes.each do |process|
      invoke "monit:#{process}:configure"
    end
    # Monit Webclient aktivieren
    if !!fetch(:monit_webclient, false)
      invoke "nginx:monit:add"
      invoke "nginx:monit:enable"
    end
    invoke "monit:syntax"
    invoke "monit:reload"
  end


  %w[start stop restart syntax reload].each do |command|
    desc "#{command.capitalize} => Monit service"
    task command do
      on roles fetch(:monit_roles) do
        execute :sudo, :service, :monit, "#{command}"
      end
    end
  end

end

namespace :nginx do
  namespace :monit do
    
    desc 'Creates MONIT WebClient configuration and upload it to the available folder'
    task :add => ['nginx:load_vars'] do
      on release_roles fetch(:nginx_roles) do
        within fetch(:sites_available) do
          config_file = fetch(:monit_nginx_template, :default)
          if config_file == :default
            magic_template("nginx_monit.conf", '/tmp/nginx_monit.conf')
          else
            magic_template(config_file, '/tmp/nginx_monit.conf')
          end
          execute :sudo, :mv, '/tmp/nginx_monit.conf', "monit_webclient"
        end
      end

      on release_roles fetch(:nginx_roles) do
        config_file = fetch(:monit_nginx_template, :default)
        puts "📤 Uploading Monit - Nginx config"
        if config_file == :default
          template2go("nginx_monit.conf", "/tmp/monit_webclient.conf")
        else
          template2go(config_file, "/tmp/monit_webclient.conf")
        end
        execute :sudo, :mv, "/tmp/monit_webclient.conf", "/etc/nginx/sites-available/monit_webclient.conf"
      end
    end
    
    desc 'Enables MONIT WebClient creating a symbolic link into the enabled folder'
    task :enable => ['nginx:load_vars'] do
      on release_roles fetch(:nginx_roles) do
        enabled_path = "/etc/nginx/sites-enabled/monit_webclient.conf}"
        available_path = "/etc/nginx/sites-available/monit_webclient.conf}"
        unless test "[ -h #{enabled_path} ]"
          puts "🔗 Enabling Nginx site..."
          execute :sudo, :ln, "-nfs", available_path, enabled_path
        else
          puts "✅ Nginx site is already enabled!"
        end
      end
    end

    desc 'Disables MONIT WebClient removing the symbolic link located in the enabled folder'
    task :disable => ['nginx:load_vars'] do
      on release_roles fetch(:nginx_roles) do
        enabled_path = "/etc/nginx/sites-enabled/monit_webclient.conf}"
        if test "[ -f #{ enabled_path } ]"
          execute :sudo, :rm, '-f', enabled_path
        end
      end
    end
    
  end
end


namespace :certbot do
  desc "Generate MONIT-WebClient LetsEncrypt certificate"
  task :monit_cert do
    on release_roles fetch(:certbot_roles) do
      execute :sudo, "certbot --non-interactive --agree-tos --email #{fetch(:lets_encrypt_email)} certonly --webroot -w #{current_path}/public -d #{ fetch(:monit_webclient).gsub(/^\*?\./, '') }"
    end
  end
end

namespace :slack do
  desc 'Upload alert_slack.sh for Monit script to server'
  task :configure_monit do
    on roles fetch(:monit_roles) do
      monit_config 'alert_slack', "#{ fetch(:monit_slack_bin_path) }"
      execute :sudo, "chmod +x  #{ fetch(:monit_slack_bin_path) }"
    end
  end
end


# Diesen Block erst ausführen, sobald load:defaults abgeschlossen ist
Rake::Task["load:defaults"].enhance do
  namespace :monit do

    namespace :task do
      # Jetzt wird monit_processes mit den gesetzten Defaults ausgewertet
      monit_processes.each do |process|
        namespace process.to_sym do

          %w[monitor unmonitor start stop restart].each do |command|
            desc "#{command.capitalize} #{process} process"
            task command do
              on roles fetch(:monit_roles) do
                monit_process_command(process, command)
              end
            end
          end

          # Server-spezifische Aufgabe zum Hochladen der Konfiguration
          desc "Upload Monit #{process} config file (server specific)"
          task :configure do
            on roles fetch(:monit_roles) do
              monit_config(process)
            end
          end

        end
      end
    end

    namespace :all do
      %w[monitor unmonitor start stop restart].each do |command|
        desc "#{command.capitalize} all processes"
        task command do
          on roles fetch(:monit_roles) do
            monit_processes.each do |process|
              monit_process_command(process, command)
            end
          end
        end
      end
    end

  end
end



namespace :deploy do
  before :starting, :stop_monitoring do
    %w[puma sidekiq thin].each do |process|
      if fetch(:monit_active) && monit_processes.include?(command)
        invoke "monit:task:#{process}:unmonitor"
      end
    end
  end
  before 'deploy:finishing', :add_monit_webclient do
    if fetch(:monit_active) && !!fetch(:monit_webclient, false)
      invoke "nginx:monit:add"
      invoke "nginx:monit:enable"
    end
  end
  after :finished, :restart_monitoring do
    %w[puma sidekiq thin].each do |process|
      if fetch(:monit_active) && monit_processes.include?(command)
        invoke "monit:task:#{process}:monitor"
      end
    end
  end
end