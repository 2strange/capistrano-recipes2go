# Capistrano Redis — Installation & Service-Steuerung

Redis auf dem Server installieren und den `redis-server`-Dienst starten,
stoppen oder neustarten.

---

## Capfile

```ruby
require 'capistrano/recipes2go/redis'
```

---

## Konfiguration

```ruby
set :redis_roles, -> { :web }                                   # Serverrolle
set :redis_pid,   -> { "/var/run/redis/redis-server.pid" }      # PID-Datei
```

---

## Tasks

### Installieren

```sh
cap production redis:install
```

Führt `apt-get install redis-server` aus und sichert die Default-Konfiguration
nach `/etc/redis/redis.conf.default`.

### Service steuern

```sh
cap production redis:start
cap production redis:stop
cap production redis:restart
```

---

## Hinweise

- Für vollständige Backups von Redis-Daten → [`db`-Recipe](db.md)
  (`set :db_backup_redis_on_deploy, true`).
- Für die Migration von Namespace-basierten Redis-Keys (Sidekiq 7+) →
  [`redis_uns`-Recipe](redis_uns.md).
- Der `server`-Recipe installiert Redis ebenfalls als Teil des
  Server-Setups (`set :srvr_install_redis, true`). Wer `server:setup` nutzt,
  braucht `redis:install` nicht separat.
