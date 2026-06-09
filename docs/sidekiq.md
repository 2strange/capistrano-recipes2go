# Capistrano Sidekiq — Background-Worker (systemd)

Sidekiq als systemd-Service(s) einrichten, deployen und steuern. Unterstützt
mehrere Sidekiq-Prozesse und spezielle Queue-Konfigurationen.

---

## Capfile

```ruby
require 'capistrano/recipes2go/sidekiq'
```

`pids` und `log` werden automatisch zu `linked_dirs` hinzugefügt.

---

## Konfiguration

```ruby
set :sidekiq_roles,           -> { :app }
set :sidekiq_service_file,    -> { "#{fetch(:application)}_#{fetch(:stage)}_sidekiq" }  # systemd-Basis-Name

# Prozesse
set :sidekiq_processes,       -> { 1 }      # Anzahl Sidekiq-Prozesse (bei mehreren: aufsteigend nummeriert)
set :sidekiq_timeout,         -> { 10 }     # Graceful-Shutdown-Timeout in Sekunden

# Queues
set :sidekiq_special_queues,  -> { false }  # true: eigene Queue-Konfiguration pro Prozess
set :sidekiq_queued_processes,-> { [] }     # Array mit Queue-Definitionen pro Prozess

# Pfade
set :sidekiq_service_path,    -> { "/lib/systemd/system" }
set :sidekiq_pid_path,        -> { "#{shared_path}/pids" }
set :sidekiq_log_path,        -> { "#{shared_path}/log" }

# Ruby-VM
set :sidekiq_ruby_vm,         -> { :rvm }   # :rvm | :rbenv | :system
set :sidekiq_user,            -> { fetch(:user, 'deploy') }

# Template
set :sidekiq_template,        -> { :default }  # :default oder eigener Template-Name

# Deploy-Verhalten
set :sidekiq_default_hooks,   -> { true }   # true: vor Deploy stoppen, nach Deploy starten
set :sidekiq_log_lines,       -> { 100 }
```

---

## Tasks

### Erstes Setup und Deploy

```sh
cap production sidekiq:setup   # Service-Datei(en) hochladen, noch nicht starten
cap production sidekiq:deploy  # setup + enable + start
```

### Service-Steuerung

```sh
cap production sidekiq:start
cap production sidekiq:stop
cap production sidekiq:restart
cap production sidekiq:enable
cap production sidekiq:disable
cap production sidekiq:quiet       # TSTP-Signal: keine neuen Jobs annehmen (für graceful drain)
cap production sidekiq:check_status
cap production sidekiq:logs        # journalctl (letzte 100 Zeilen)
```

### Service-Datei aktualisieren

```sh
cap production sidekiq:upload_services  # Service-Datei(en) neu hochladen + daemon-reload
```

---

## Deploy-Hooks

Mit `sidekiq_default_hooks: true` (Standard):

- **Vor** `deploy:starting`: Sidekiq stoppen
- **Nach** `deploy:finished`: Sidekiq starten

Bei mehreren Prozessen (`sidekiq_processes: 2`) werden alle Service-Dateien
automatisch mit aufsteigendem Suffix angelegt (z.B. `myapp_production_sidekiq_1`,
`myapp_production_sidekiq_2`).
