# Capistrano Thin — App-Server (systemd)

Thin als systemd-Service einrichten, konfigurieren und steuern. Thin ist die
Alternative zu Puma — für ältere Rails-Apps oder wenn Thin explizit gewünscht
ist.

Für neue Projekte wird **Puma** empfohlen. Thin ist weiterhin vollständig unterstützt.

---

## Capfile

```ruby
require 'capistrano/recipes2go/thin'
```

`config/thin_app_<stage>.yml` wird automatisch zu `linked_files` hinzugefügt.

---

## Konfiguration

```ruby
set :thin_roles,                  -> { :web }
set :thin_daemon_file,            -> { "#{fetch(:application)}_#{fetch(:stage)}_thin" }  # systemd-Service-Name

# Thin-Prozess-Settings
set :thin_servers,                -> { fetch(:app_instances, 1) }  # Anzahl Thin-Instanzen
set :thin_timeout,                -> { 42 }                        # Sekunden bis Timeout
set :thin_max_conns,              -> { 1024 }
set :thin_max_persistent_conns,   -> { 512 }
set :thin_wait,                   -> { 90 }                        # Sekunden warten beim Restart
set :thin_onebyone,               -> { true }                      # Instanzen einzeln neustarten
set :thin_require,                -> { [] }                        # Zusätzliche require-Files
set :thin_daemonize,              -> { false }                     # Thin darf sich nicht selbst daemonisieren (systemd übernimmt)

# Pfade
set :thin_path,                   -> { '/etc/thin' }
set :thin_daemon_path,            -> { "/lib/systemd/system" }
set :thin_pid_path,               -> { "#{shared_path}/pids" }

# Ruby-VM
set :thin_daemon_ruby_vm,         -> { :rvm }   # :rvm | :rbenv | :system
set :thin_daemon_user,            -> { fetch(:user, 'deploy') }

# Template
set :thin_daemon_template,        -> { :default }

# Deploy-Verhalten
set :thin_hooks,                  -> { true }   # true: nach deploy:published reconf + restart
set :thin_daemon_log_lines,       -> { 100 }
```

---

## Tasks

### Erstes Setup

```sh
cap production thin:setup     # Service-Datei + thin-Config hochladen (noch nicht starten)
cap production thin:activate  # Service aktivieren + starten
```

### Service-Steuerung

```sh
cap production thin:start
cap production thin:stop
cap production thin:restart
cap production thin:enable
cap production thin:disable
cap production thin:quiet       # TSTP-Signal: graceful drain
cap production thin:check_status
cap production thin:logs        # journalctl (letzte 100 Zeilen)
```

### Konfiguration aktualisieren

```sh
cap production thin:reconf       # Nur thin-Config (thin_app_<stage>.yml) hochladen
cap production thin:upload_daemon  # Nur systemd-Service-Datei hochladen
```

### Aufräumen

```sh
cap production thin:remove_old_services  # Alte Service-Dateien im alten Namensformat entfernen
```

---

## Deploy-Hook

Mit `thin_hooks: true` (Standard) wird nach `deploy:published` automatisch
`thin:reconf` + `thin:restart` aufgerufen.
