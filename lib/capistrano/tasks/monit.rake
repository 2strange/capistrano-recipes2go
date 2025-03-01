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

    # File-Monitoring: Überwacht Dateien (z. B. Log-Dateien)
    set :monit_files_to_check,        -> { [] }

    # URL für m/Monit API oder eigenen Service
    set :monit_mmonit_url,            -> { false }

    # Slack-Alerts: Sendet Benachrichtigungen via Slack API
    set :monit_use_slack,             -> { false }
    set :monit_slack_webhook,         -> { "" }  # Slack Webhook URL
    set :monit_slack_bin_path,        -> { "/etc/monit/alert_slack.sh" }
    
  end
end
