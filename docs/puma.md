# Capistrano Puma — App-Server (systemd)

Puma als systemd-Service einrichten, konfigurieren und steuern. Puma ist der
Standard-App-Server für Rails-Apps in diesem Setup.

---

## Capfile

```ruby
require 'capistrano/recipes2go/puma'
```

`config/puma.rb` wird automatisch zu `linked_files` hinzugefügt. `log`, `pids`
und `tmp/sockets` werden zu `linked_dirs` hinzugefügt.

---

## Konfiguration

```ruby
set :puma_roles,           -> { :app }
set :puma_service_file,    -> { "#{fetch(:application)}_#{fetch(:stage)}_puma" }  # systemd-Service-Name

# Pfade
set :puma_systemd_path,    -> { "/lib/systemd/system" }
set :puma_pid_path,        -> { "#{shared_path}/pids" }
set :puma_socket_path,     -> { "#{shared_path}/tmp/sockets" }
set :puma_state,           -> { "#{shared_path}/puma.state" }
set :puma_log_path,        -> { "#{shared_path}/log/puma.log" }

# Performance
set :puma_workers,         -> { fetch(:app_instances, 1) }  # Anzahl Worker-Prozesse
set :puma_threads,         -> { [4, 8] }                    # [min, max] Threads pro Worker
set :puma_preload_app,     -> { true }

# Ruby-VM
set :puma_ruby_vm,         -> { :rvm }     # :rvm | :rbenv | :system
set :puma_user,            -> { fetch(:user, 'deploy') }

# Deploy-Verhalten
set :puma_hooks,           -> { true }     # true: nach deploy:published automatisch neustarten
set :puma_semantic_logger, -> { true }     # Semantic Logger aktivieren
set :puma_log_lines,       -> { 100 }      # Anzahl Log-Zeilen bei puma:logs
```

**Performance-Richtwerte:**

| Traffic | Worker | Threads |
|---|---|---|
| Klein (low traffic) | 1 | `[4, 8]` |
| Mittel | 2 | `[8, 16]` |
| Groß (high traffic) | 4+ | `[16, 32]` |

---

## Tasks

### Erstes Setup

```sh
cap production puma:setup     # Service-Datei + puma.rb hochladen (noch nicht starten)
cap production puma:activate  # Service aktivieren + starten
```

Oder in einem Schritt:

```sh
cap production puma:configure  # setup + activate + enable_if_needed
```

### Service-Steuerung

```sh
cap production puma:start
cap production puma:stop
cap production puma:restart
cap production puma:enable
cap production puma:disable
cap production puma:is_enabled     # Status abfragen
cap production puma:check_status   # systemctl status ausgeben
cap production puma:logs           # journalctl (letzte 100 Zeilen)
```

### Konfiguration aktualisieren

```sh
cap production puma:upload_service  # Nur systemd-Service-Datei hochladen
cap production puma:upload_config   # Nur puma.rb hochladen
```

### Aufräumen

```sh
cap production puma:remove_old_services  # Alte Service-Dateien im alten Namensformat entfernen
```

---

## Deploy-Hook

Mit `puma_hooks: true` (Standard) wird nach `deploy:published` automatisch
`puma:upload_config` + `puma:enable_if_needed` + `puma:restart` aufgerufen.
