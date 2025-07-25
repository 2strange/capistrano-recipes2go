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
    set :monit_start_delay,           -> { 120 }  # Verzögerung in Sekunden, bevor Monit startet
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
    set :monit_mail_authentication,   -> { "AUTO" }  # Optionen: SSLAUTO|SSLV2|SSLV3|TLSV1|TLSV11|TLSV12
    set :monit_mail_username,         -> { "foo@example.com" }
    set :monit_mail_password,         -> { "secret" }
    set :monit_mail_to,               -> { "foo@example.com" }
    set :monit_mail_from,             -> { "monit@foo.bar" }
    set :monit_mail_reply_to,         -> { "support@foo.bar" }

    set :monit_ignore,                -> { %w[action instance] }  # z. B. %w[action pid]

    ## System-Checks:
    # now checked per core so this is kind of obsolete
    set :monit_max_load_avg,          -> { nil }  # Maximale durchschnittliche Systemlast (CPUs des Systems berücksichtigen, z. B. 2 CPUs = 2, 4 CPUs = 4, etc.)
    
    set :monit_max_memory_percent,    -> { 75 }
    set :monit_max_cpu_percent,       -> { 95 }
    set :monit_max_hdd_percent,       -> { 75 }

    # Zusätzliche Einstellungen für PostgreSQL
    set :monit_pg_pid,                -> { "/var/run/postgresql/17-main.pid" }

    # Einstellungen für Redis
    set :monit_redis_pid,             -> { fetch(:redis_pid, "/var/run/redis/redis-server.pid") }

    # Einstellungen für Puma (benötigt secrets_key_base)
    set :monit_puma_totalmem_mb,      -> { 3072 }
    set :monit_puma_pid_path,         -> { fetch(:puma_pid_path, "#{shared_path}/pids") }

    # Einstellungen für Thin (benötigt secrets_key_base)
    set :monit_thin_totalmem_mb,      -> { 2048 }
    set :monit_thin_pid_path,         -> { fetch(:thin_pid_path, "#{shared_path}/pids") }

    # Einstellungen für Sidekiq (ehemals sidekiq_six, jetzt in "sidekiq" umbenannt)
    set :monit_sidekiq_totalmem_mb,   -> { 2048 }
    set :monit_sidekiq_timeout_sec,   -> { 90 }
    set :monit_sidekiq_pid_path,      -> { fetch(:sidekiq_pid_path, "#{shared_path}/pids") }  # Variable an Sidekiq angepasst

    # WebClient-Einstellungen: Erlaubt den externen Zugriff via nginx (mit optionaler SSL-Verschlüsselung)
    set :monit_http_port,             -> { 2812 }
    set :monit_http_username,         -> { "xaxdxmxixnx" }
    set :monit_http_password,         -> { "zmzoznziztzozrz" }
    set :monit_webclient,             -> { false }  # Domain für den Webclient
    set :monit_webclient_ssl,         -> { false }  # Nutzt SSL für den WebClient
    set :monit_webclient_ssl_cert,    -> { "/etc/letsencrypt/live/#{fetch(:monit_webclient)}/fullchain.pem" }
    set :monit_webclient_ssl_key,     -> { "/etc/letsencrypt/live/#{fetch(:monit_webclient)}/privkey.pem" }
    set :monit_nginx_template,        -> { :default }
    set :monit_nginx_roles,           -> { fetch(:nginx_roles, :web) }  # Nginx-Rollen für den Webclient


    # Website-Monitoring: Statt der alten :monit_website_check_*-Variablen wird nun :monit_websites_to_check genutzt
    # Website: { name: String, domain: String, ssl: Boolean, check_content: Boolean, path: String, content: String, path: String, cycles: Integer, timeout: Integer }
    set :monit_websites_to_check,     -> { [] }

    ## check other Hosts:
    set :monit_hosts_to_check,        -> { [] }
    # Website: { name: String, host: String, port: Integer, protocol: String, cycles: Integer }


    # File-Monitoring: Überwacht Dateien (z. B. Log-Dateien)
    # FILE: { name: String, path: String, max_size: Integer, clear: Boolean }
    set :monit_files_to_check,        -> { [] }

    ## Check directories
    set :monit_folders_to_check,      -> { [] }
    ## FOLDER: { name: String, path: String, max_size: Integer }


    # URL für m/Monit API oder eigenen Service (monitr)
    set :monit_mmonit_url,            -> { false }


    # m/Monit API: Sendet Benachrichtigungen via m/Monit API
    set :monit_event_api_url,         -> { false }
    set :monit_event_api_bin_path,    -> { "/etc/monit/alert_event.sh" }


    # Slack-Alerts: Sendet Benachrichtigungen via Slack API
    set :monit_use_slack,             -> { false }
    set :monit_slack_webhook,         -> { "" }  # Slack Webhook URL
    set :monit_slack_bin_path,        -> { "/etc/monit/alert_slack.sh" }

  end
end


namespace :monit do

  desc "Install Monit"
  task :install do
    on roles fetch(:monit_roles) do
      ensure_monit_installed
    end
  end

  desc 'Upload alert_event.sh for Monit script to server'
  task :configure_event_script do
    on roles fetch(:monit_roles) do
      monit_config 'alert_event', "#{ fetch(:monit_event_api_bin_path) }"
      execute :sudo, "chmod +x  #{ fetch(:monit_event_api_bin_path) }"
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
      invoke "monit:task:#{process}:configure"
    end
    if fetch(:monit_use_slack, false)
      invoke "slack:configure_monit"
    end
    if fetch(:monit_event_api_url, false)
      invoke "monit:configure_event_script"
    end
    # Monit Webclient aktivieren
    if !!fetch(:monit_webclient, false)
      invoke "nginx:monit:add"
      invoke "nginx:monit:enable"
    end
    invoke "monit:syntax"
    invoke "monit:reload"
  end


  %w[start stop restart reload syntax status].each do |command|
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
    task :add do
      on roles fetch(:monit_nginx_roles) do
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
    task :enable do
      on roles fetch(:monit_nginx_roles) do
        enabled_path = "/etc/nginx/sites-enabled/monit_webclient.conf"
        available_path = "/etc/nginx/sites-available/monit_webclient.conf"
        unless test "[ -h #{enabled_path} ]"
          puts "🔗 Enabling Nginx site..."
          execute :sudo, :ln, "-nfs", available_path, enabled_path
        else
          puts "✅ Nginx site is already enabled!"
        end
      end
    end

    desc 'Disables MONIT WebClient removing the symbolic link located in the enabled folder'
    task :disable do
      on roles fetch(:monit_nginx_roles) do
        enabled_path = "/etc/nginx/sites-enabled/monit_webclient.conf}"
        if test "[ -f #{ enabled_path } ]"
          execute :sudo, :rm, '-f', enabled_path
        end
      end
    end
    
  end
end


namespace :certbot do

  desc "MONIT-WebClient: Generate LetsEncrypt certificate"
  task :monit_cert do
    on release_roles fetch(:certbot_roles) do
      certbot_email = fetch(:certbot_email, "").strip
      if certbot_email.empty?
        puts "⚠️  No email address is set for Let's Encrypt!"
        puts "➡️  A valid email is required to receive expiration notifications."
        puts "➡️  Please enter a valid email address:"
        ask(:certbot_email, "Enter email for Let's Encrypt:")
        set(:certbot_email, fetch(:certbot_email)) # Store response
      end
      execute :sudo, "certbot --non-interactive --agree-tos --email #{fetch(:certbot_email)} certonly --webroot -w #{current_path}/public -d #{ fetch(:monit_webclient).gsub(/^\*?\./, '') }"
    end
  end

  desc 'MONIT-WebClient: Run Certbot to validate the DNS challenge'
  task :monit_dns_challenge do
    on release_roles fetch(:certbot_roles) do
      within release_path do
        certbot_email = fetch(:certbot_email, "").strip
        if certbot_email.empty?
          puts "⚠️  No email address is set for Let's Encrypt!"
          puts "➡️  A valid email is required to receive expiration notifications."
          puts "➡️  Please enter a valid email address:"
          ask(:certbot_email, "Enter email for Let's Encrypt:")
          set(:certbot_email, fetch(:certbot_email)) # Store response
        end
        user = fetch(:user, "deploy") # Adjust to your user

        puts "cmd: sudo certbot certonly --manual --preferred-challenges=dns --agree-tos --email #{fetch(:certbot_email)} -d #{ fetch(:monit_webclient).gsub(/^\*?\./, '') }"

        puts "🔄 Starting interactive Certbot session..."
        system("ssh -t #{user}@#{host.hostname} 'sudo certbot certonly --manual --preferred-challenges=dns --agree-tos --email #{fetch(:certbot_email)} -d #{ fetch(:monit_webclient).gsub(/^\*?\./, '') }'")
      end
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
      # monit_processes.each do |process| ## doesn't work here
      %w[nginx postgresql redis sidekiq thin puma websites files hosts folders].each do |process|
        namespace process.to_sym do

          %w[monitor unmonitor start stop restart status summary].each do |command|
            desc "#{command.capitalize} #{process} process"
            task command do
              on roles fetch(:monit_roles) do
                monit_process_command(process, command) if monit_processes.include?(process)
              end
            end
          end

          # Server-spezifische Aufgabe zum Hochladen der Konfiguration
          desc "Upload Monit #{process} config file (server specific)"
          task :configure do
            on roles fetch(:monit_roles) do
              monit_config(process) if monit_processes.include?(process)
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
      if fetch(:monit_active) && monit_processes.include?(process)
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
      if fetch(:monit_active) && monit_processes.include?(process)
        invoke "monit:task:#{process}:monitor"
      end
    end
  end
end