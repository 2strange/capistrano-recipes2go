# Quickstart — Standard Rails-API-Deploy

Minimale Schritt-für-Schritt-Anleitung für ein vollständiges Rails-API-Deployment
mit `capistrano-recipes2go`: frischer Server → laufende App.

---

## 1. Gem einbinden

```ruby
# Gemfile
group :development do
  gem "capistrano-recipes2go", require: false, github: "2strange/capistrano-recipes2go"
end
```

```sh
bundle install
```

---

## 2. Capfile einrichten

```ruby
# Capfile
require "capistrano/rvm"
require "capistrano/bundler"
require "capistrano/rails/assets"
require "capistrano/rails/migrations"

require 'capistrano/recipes2go/server'      # Einmalig: Server-Setup
require 'capistrano/recipes2go/postgresql'  # DB anlegen + database.yml
require 'capistrano/recipes2go/keys'        # master.key + credentials hochladen
require 'capistrano/recipes2go/certbot'     # Let's Encrypt
require 'capistrano/recipes2go/nginx'       # Nginx (Single-Server) ...
# ODER:
# require 'capistrano/recipes2go/proxy_nginx'  # ... Nginx (Proxy-Setup)
require 'capistrano/recipes2go/puma'        # Puma App-Server
require 'capistrano/recipes2go/sidekiq'     # Sidekiq Background-Worker
require 'capistrano/recipes2go/db'          # DB-Backups vor Deploy
```

---

## 3. `config/deploy.rb` (Minimal)

```ruby
set :application, "my_api"
set :repo_url,    "git@github.com:you/my_api.git"
set :branch,      "main"
set :user,        "deploy"

set :deploy_to,   "/home/deploy/my_api_production"

# Nginx
set :nginx_domains,   ['api.example.com']
set :nginx_use_ssl,   true

# SSL
set :certbot_email,   "mail@example.com"
set :certbot_roles,   [:web]

# DB-Backup vor Deploy
set :db_backup_pg_on_deploy,   true
set :db_backup_yaml_on_deploy, false
```

---

## 4. Einmalig: Server einrichten

```sh
# WICHTIG: Nur das server-Recipe im Capfile haben beim ersten Mal!
bundle exec cap production server:setup
```

Installiert: RVM + Ruby, NVM + Node.js, Nginx, PostgreSQL, Redis, Certbot, UFW.

Danach alle weiteren Recipes ins Capfile aufnehmen.

---

## 5. Einmalig: Infrastruktur aufsetzen

In dieser Reihenfolge:

```sh
bundle exec cap production postgresql:setup   # DB + User + database.yml
bundle exec cap production keys:setup          # master.key + credentials hochladen
bundle exec cap production setup               # Nginx-Config + Puma-Service + Sidekiq-Service hochladen
bundle exec cap production nginx:site:enable   # Nginx-Site aktivieren
bundle exec cap production puma:activate       # Puma starten
bundle exec cap production sidekiq:deploy      # Sidekiq starten
```

---

## 6. SSL-Zertifikat

```sh
bundle exec cap production certbot:install         # certbot installieren
bundle exec cap production certbot:generate        # Zertifikat anfordern
bundle exec cap production certbot:setup_auto_renew  # Auto-Renew einrichten
```

---

## 7. Erstes Deployment

```sh
bundle exec cap production deploy
```

Läuft dabei automatisch ab:
- DB-Backup (pg_dump, falls konfiguriert)
- `bundle install`
- Asset-Precompile
- DB-Migrationen
- Puma neustarten
- Sidekiq neustarten
- Nginx-Config aktualisieren + reload

---

## Für spätere Deployments

```sh
bundle exec cap production deploy
```

Das war's. Alle Hooks greifen automatisch.

---

## Optionale Extras (nach Bedarf hinzufügen)

```ruby
# Capfile
require 'capistrano/recipes2go/monit'    # Prozess-Monitoring
require 'capistrano/recipes2go/dragonfly'  # Attachment-Sync
require 'capistrano/recipes2go/systemd'  # Log-Cleanup via systemd-Timer
require 'capistrano/recipes2go/ufw'      # UFW-Firewall manuell verwalten
require 'capistrano/recipes2go/nvm'      # NVM separat verwalten
```

---

## Proxy-Setup (Proxy-Server → App-Server)

Statt `nginx` das `proxy_nginx`-Recipe verwenden:

```ruby
require 'capistrano/recipes2go/proxy_nginx'
```

```ruby
# config/deploy/production.rb
server '1.2.3.4',   user: 'deploy', roles: %w{proxy},       no_release: true
server '10.0.0.5',  user: 'deploy', roles: %w{app web db}

set :nginx_upstream_host, '10.0.0.5'
set :nginx_upstream_port, 4550
set :certbot_roles, [:proxy]
```

Doku: [proxy_nginx.md](proxy_nginx.md) · [certbot.md](certbot.md)
