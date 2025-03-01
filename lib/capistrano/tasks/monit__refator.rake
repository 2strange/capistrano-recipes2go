# ===============================================
# Aktualisierte Konfiguration für Recipes2go
# (ehemals MagicRecipes)
# ===============================================
require 'capistrano/recipes2go/base_helpers'      # Namespace geändert von magic_recipes zu recipes2go
require 'capistrano/recipes2go/sidekiq_helpers'    # Namespace geändert von magic_recipes zu recipes2go
include Capistrano::Recipes2go::SidekiqHelpers       # Namespace geändert
include Capistrano::Recipes2go::BaseHelpers          # Namespace geändert

namespace :load do
  task :defaults do
    # Basis-Einstellungen für Monit
    set :monit_roles,                 -> { :web }
    set :monit_interval,              -> { 60 }
    set :monit_bin,                   -> { '/usr/bin/monit' }
    set :monit_logfile,               -> { "#{shared_path}/log/monit.log" }  # Default in Monit: /var/log/monit.log
    set :monit_idfile,                -> { '/var/lib/monit/id' }
    set :monit_statefile,             -> { '/var/lib/monit/state' }

    # Status und RC-Datei: Nur eine Seite soll das RC schreiben, wenn mehrere auf einem Server Monit nutzen
    set :monit_active,                -> { true }
    set :monit_main_rc,               -> { true }

    # Definierte Prozesse. 
    # Hinweis: Der alte Namespace "sidekiq" entfällt – es wird nur noch sidekiq_six genutzt, 
    # der nun in "sidekiq" umbenannt wurde. PM2 wurde entfernt (ist fürs Frontend gedacht).
    set :monit_processes,             -> { %w[nginx postgresql thin website sidekiq redis pwa] }

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
    set :monit_http_client,           -> { true }
    set :monit_http_port,             -> { 2812 }
    set :monit_http_username,         -> { "admin" }
    set :monit_http_password,         -> { "monitor" }
    set :monit_webclient,             -> { false }  # Aktiviert nginx-Config für den Monit WebClient
    set :monit_webclient_domain,      -> { false }  # Domain für den Webclient
    set :monit_webclient_use_ssl,     -> { false }
    set :monit_webclient_ssl_cert,    -> { false }
    set :monit_webclient_ssl_key,     -> { false }
    set :monit_nginx_template,        -> { :default }

    # Website-Monitoring: Statt der alten :monit_website_check_*-Variablen wird nun :monit_websites_to_check genutzt
    set :monit_websites_to_check,     -> { [] }

    # URL für m/Monit API oder eigenen Service
    set :monit_mmonit_url,            -> { false }

    # PM2-Block entfernt, da dieser vorerst nicht benötigt wird (eher Frontend-bezogen)

    # File-Monitoring: Überwacht Dateien (z. B. Log-Dateien)
    set :monit_files_to_check,        -> { [] }

    # Slack-Alerts: Sendet Benachrichtigungen via Slack API
    set :monit_use_slack,             -> { false }
    set :monit_slack_webhook,         -> { "" }  # Slack Webhook URL
    set :monit_slack_bin_path,        -> { "/etc/monit/alert_slack.sh" }
  end
end

namespace :monit do
  desc "Installiere Monit"
  task :install do
    on release_roles fetch(:monit_roles) do
      execute :sudo, "apt-get update"
      execute :sudo, "apt-get -y install monit"
    end
  end
  # after "deploy:install", "monit:install"

  desc "Erstelle alle Monit-Konfigurationen"
  task :setup do
    on release_roles fetch(:monit_roles) do
      # Falls aktiv, soll nur eine Seite die Haupt-RC-Datei schreiben
      if fetch(:monit_main_rc, false)
        monit_config "monitrc", "/etc/monit/monitrc"
      end
      # Konfiguration der einzelnen Prozesse (ohne PM2, website_checks und file_checks)
      %w[nginx postgresql pwa redis sidekiq thin thin_sysd].each do |process|
        invoke "monit:#{process}:configure" if Array(fetch(:monit_processes)).include?(process)
      end
      # Konfiguriere den WebClient via nginx, falls aktiviert
      if fetch(:monit_webclient, false) && fetch(:monit_webclient_domain, false)
        invoke "nginx:monit:add"
        invoke "nginx:monit:enable"
      end
    end
    invoke "monit:syntax"
    invoke "monit:reload"

    # Neue Tasks für Website- und File-Monitoring basierend auf den neuen Variablen
    invoke "monit:websites:configure" if fetch(:monit_websites_to_check).any?
    invoke "monit:files:configure" if fetch(:monit_files_to_check).any?
  end
  # after "deploy:setup", "monit:setup"

  desc 'Downgrade MONIT auf 5.16 (behebt Action-Problem)'
  task :downgrade_system do
    on roles :db do
      execute :sudo, 'apt-get -y install monit=1:5.16-2 --allow-downgrades'
    end
  end

  # Prozess-spezifische Tasks für Monit-Befehle
  %w[nginx postgresql redis sidekiq thin thin_sysd pwa].each do |process|
    namespace process.to_sym do

      %w[monitor unmonitor start stop restart].each do |command|
        desc "#{command} Monit-Service für: #{process}"
        task command do
          if Array(fetch(:monit_processes)).include?(process)
            on roles(fetch("#{process}_roles".to_sym)) do
              if process == "sidekiq"
                # Für Sidekiq werden mehrere Instanzen verwaltet
                sidekiq_processes_count.times do |idx|
                  execute :sudo, "#{fetch(:monit_bin)} #{command} #{sidekiq_service_name(idx)}"
                end
              elsif process == "thin"
                fetch(:app_instances).times do |idx|
                  execute :sudo, "#{fetch(:monit_bin)} #{command} #{fetch(:application)}_#{fetch(:stage)}_thin_#{idx}"
                end
              else
                execute :sudo, "#{fetch(:monit_bin)} #{command} #{process}"
              end
            end
          end
        end
      end

      if %w[nginx postgresql redis].include?(process)
        # Server-spezifische Tasks
        desc "Lade Monit #{process} Konfigurationsdatei hoch (server-spezifisch)"
        task "configure" do
          if Array(fetch(:monit_processes)).include?(process)
            on release_roles fetch("#{process}_roles".to_sym) do |role|
              monit_config(process, nil, role)
            end
          end
        end
      elsif %w[pwa sidekiq thin thin_sysd].include?(process)
        # App-spezifische Tasks
        desc "Lade Monit #{process} Konfigurationsdatei hoch (app-spezifisch)"
        task "configure" do
          puts "Konfiguriere Monit für #{process}"  # Debug-Ausgabe
          if Array(fetch(:monit_processes)).include?(process)
            on release_roles fetch("#{process}_roles".to_sym) do |role|
              monit_config(process, "/etc/monit/conf.d/#{fetch(:application)}_#{fetch(:stage)}_#{process}.conf", role)
            end
          end
        end
      end

    end
  end

  # Neuer Namespace für Website-Monitoring (basierend auf :monit_websites_to_check)
  namespace :websites do
    desc "Lade Monit-Konfigurationen für überwachte Websites hoch"
    task :configure do
      Array(fetch(:monit_websites_to_check)).each do |site|
        # Initialisiere Website-Konfiguration mit Standardwerten
        site_config = init_site_check_item(site)
        on release_roles(fetch(:nginx_roles, :web)) do |role|
          # Verwende :monit_name als Präfix für RC-Dateien
          destination = "/etc/monit/conf.d/#{fetch(:monit_name)}_website_#{site_config[:name]}.conf"
          monit_config("website_#{site_config[:name]}", destination, role)
        end
      end
    end
  end

  # Neuer Namespace für File-Monitoring (basierend auf :monit_files_to_check)
  namespace :files do
    desc "Lade Monit-Konfigurationen für zu überwachende Dateien hoch"
    task :configure do
      Array(fetch(:monit_files_to_check)).each do |file|
        file_config = init_file_check_item(file)
        on release_roles(fetch(:nginx_roles, :web)) do |role|
          destination = "/etc/monit/conf.d/#{fetch(:monit_name)}_file_#{file_config[:name]}.conf"
          monit_config("file_#{file_config[:name]}", destination, role)
        end
      end
    end
  end

  namespace :slack do
    desc 'Konfiguriere Slack-Alerts für Monit'
    task :configure do
      on roles :db do
        on release_roles fetch(:monit_roles) do |role|
          monit_config('alert_slack', "#{ fetch(:monit_slack_bin_path) }", role)
          execute :sudo, "chmod +x #{ fetch(:monit_slack_bin_path) }"
        end
      end
    end
  end

  %w[start stop restart syntax reload].each do |command|
    desc "Führe Monit #{command} Befehl aus"
    task command do
      on release_roles fetch(:monit_roles) do
        execute :sudo, :service, :monit, "#{command}"
      end
    end
  end

  # Hilfsmethode für den Sidekiq-Service-Namen (wird für alle Instanzen verwendet)
  def sidekiq_service_name(index=nil)
    fetch(:sidekiq_service_name, "#{fetch(:application)}_#{fetch(:stage)}_sidekiq_") + index.to_s
  end

end

namespace :deploy do
  before :starting, :stop_monitoring do
    invoke "monit:downgrade_system" if fetch(:monit_downgrade_on_deploy, false)
    %w[sidekiq thin].each do |command|
      if fetch(:monit_active) && Array(fetch(:monit_processes)).include?(command)
        invoke "monit:#{command}:unmonitor"
      end
    end
  end

  before 'deploy:finishing', :add_monit_webclient do
    if fetch(:monit_webclient, false) && fetch(:monit_webclient_domain, false)
      invoke "nginx:monit:add"
      invoke "nginx:monit:enable"
    end
  end

  after :finished, :restart_monitoring do
    %w[sidekiq thin].each do |command|
      if fetch(:monit_active) && Array(fetch(:monit_processes)).include?(command)
        invoke "monit:#{command}:monitor"
      end
    end
  end
end

desc 'Server-Setup-Aufgaben'
task :setup do
  invoke "monit:setup" if fetch(:monit_active)
end

# ============================================================
# Helper-Methoden (alle in einem Bereich für bessere Übersicht)
# ============================================================
# Lädt eine Monit-Konfigurationsdatei aus einer Template-Datei hoch.
def monit_config(name, destination = nil, role = nil)
  destination ||= "/etc/monit/conf.d/#{name}.conf"
  template2go "monit/#{name}", "/tmp/monit_#{name}", role
  execute :sudo, "mv /tmp/monit_#{name} #{destination}"
  execute :sudo, "chown root #{destination}"
  execute :sudo, "chmod 600 #{destination}"
end

# Gibt einen Command-Prefix basierend auf dem angegebenen Role zurück (sh, bash oder user)
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

# Bereitet einen Befehl mit dem entsprechenden Role-Prefix für den App-Worker vor.
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

# Initialisiert die Website-Überwachungskonfiguration mit Standardwerten.
def init_site_check_item(domain)
  defaults = { ssl: false, check_content: false, path: '/', content: '<!DOCTYPE html>', timeout: 30, cycles: 3 }
  defaults.merge!(domain)
  defaults[:name] = defaults[:domain] if [nil, '', ' '].include?(defaults[:name])
  defaults
end

# Initialisiert die File-Überwachungskonfiguration mit Standardwerten.
def init_file_check_item(file)
  defaults = { name: '', path: '', max_size: 12, clear: false }
  defaults.merge!(file)
  defaults[:name] = defaults[:path].to_s.split('/').last if [nil, '', ' '].include?(defaults[:name])
  defaults
end

# Liefert die Liste der zu überwachenden Websites (falls vorhanden)
def monit_websites_list
  Array(fetch(:monit_websites_to_check))
end

# Liefert die Liste der zu überwachenden Dateien (falls vorhanden)
def monit_files_list
  Array(fetch(:monit_files_to_check))
end

# Gibt die Alert-Konfiguration zurück (Slack oder Standard-Alert)
def monit_alert
  if fetch(:monit_use_slack, false)
    "exec #{fetch(:monit_slack_bin_path)} and repeat every 3 cycles"
  else
    "alert"
  end
end
