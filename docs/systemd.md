# 🧼 Rails Log Cleanup mit systemd und Capistrano

Dieses Setup sorgt dafür, dass alte Rails-Logdateien automatisch gelöscht werden – z. B. `staging.log.2024-05-29`, `production.log.2024-05-28` etc.

---

## 🔧 Voraussetzungen

### 1. Rails so konfigurieren, dass tägliche Log-Dateien erstellt werden

```ruby
# config/environments/production.rb (oder staging.rb)
config.logger = ActiveSupport::Logger.new(Rails.root.join("log/#{Rails.env}.log"), 'daily')
```

---

## 🚀 Capistrano-Integration

```ruby
# config/deploy.rb oder deploy/staging.rb
set :systemd_roles,        -> { :app }    # Server-Rolle für systemd
set :keep_logs_for_days,   -> { 14 }      # So viele tägliche Logs werden behalten
```

---



## 🧪 Verwendung

### Setup starten

```bash
cap staging systemd:daily_log_cleanup
```

### Timer prüfen

```bash
cap staging systemd:log_cleanup_timers
```

### Letzte Cleanup-Logs anzeigen

```bash
cap staging systemd:log_cleanup_journal
```

---

## ✅ Manuell starten (optional)

```bash
sudo systemctl start myapp_staging_log_cleanup.service
```

---

## 🔍 Ergebnis

* Täglich wird `log/staging.log.YYYY-MM-DD` (oder `production.log.*`) überprüft
* Es bleiben nur `N = keep_logs_for_days` Dateien erhalten
* systemd sorgt automatisch für Ausführung und Stabilität
