# Capistrano Nginx — Single-Server-Setup

Nginx-Konfiguration für ein **einfaches Single-Server-Setup**: eine Nginx-Instanz
bedient die App direkt (kein separater Proxy-Server). Für ein Setup mit getrenntem
Proxy- und App-Server → [`proxy_nginx.md`](proxy_nginx.md).

---

## Capfile

```ruby
require 'capistrano/recipes2go/nginx'
```

---

## Konfiguration

```ruby
# Domains
set :nginx_domains,           -> { [] }          # Alle Domains der App, z.B. ['example.com', 'www.example.com']
set :nginx_major_domain,      -> { false }        # Haupt-Domain für Umleitungen (www → non-www)
set :nginx_remove_www,        -> { true }         # true: www-Variante auf Haupt-Domain umleiten

# SSL
set :nginx_use_ssl,           -> { false }        # true: HTTPS aktivieren
set :nginx_also_allow_http,   -> { false }        # true: HTTP zusätzlich erlauben (nicht empfohlen mit SSL)
set :nginx_strict_security,   -> { fetch(:nginx_use_ssl, false) }  # HSTS-Header
set :nginx_ssl_cert,          -> { "/etc/letsencrypt/live/<domain>/fullchain.pem" }
set :nginx_ssl_key,           -> { "/etc/letsencrypt/live/<domain>/privkey.pem" }
set :nginx_ocsp_stapling,     -> { false }        # Let's Encrypt unterstützt kein Stapling mehr (seit 2025)

# App-Server
set :nginx_roles,             -> { :web }
set :nginx_site_name,         -> { "#{fetch(:application)}_#{fetch(:stage)}" }
set :nginx_template,          -> { :default }     # :default oder eigener Template-Name
set :nginx_log_path,          -> { "#{shared_path}/log" }
set :nginx_static_dir,        -> { "#{current_path}/public" }
set :rails_app_server,        -> { :puma }        # :puma oder :thin
set :app_instances,           -> { 1 }
set :nginx_hooks,             -> { true }          # Nginx nach jedem Deploy automatisch neu laden

# Certbot-Challenge
set :allow_well_known,        -> { true }          # .well-known-Pfad für certbot freigeben
```

### Proxy-Caching (optional)

```ruby
# Rails-Antworten cachen
set :proxy_cache_rails,           -> { false }
set :proxy_cache_rails_name,      -> { "RAILS_myapp_production_CACHE" }
set :proxy_cache_rails_size,      -> { "4m" }       # Keys-Zone-Größe
set :proxy_cache_rails_time,      -> { "24h" }       # Inaktivitäts-TTL
set :proxy_cache_rails_max,       -> { "1g" }        # Max. Cache-Größe
set :proxy_cache_rails_200,       -> { false }        # TTL für 200/302-Antworten (false = kein Caching)
set :proxy_cache_rails_404,       -> { "60m" }        # TTL für 404-Antworten

# Dragonfly/Medien-Pfad cachen
set :proxy_cache_media,           -> { false }
set :proxy_cache_media_path,      -> { "media" }      # URL-Pfad-Prefix
set :proxy_cache_media_size,      -> { "2m" }
set :proxy_cache_media_time,      -> { "48h" }
set :proxy_cache_media_max,       -> { "1g" }
```

---

## Tasks

### Erstes Setup

```sh
cap production setup                # Nginx-Config hochladen + sites-available anlegen
cap production nginx:site:enable    # Site aktivieren (Symlink in sites-enabled)
```

### Konfiguration aktualisieren

```sh
cap production nginx:site:upload    # Config neu hochladen
cap production nginx:update         # Upload + Enable (falls nötig) + Restart
```

### Site-Verwaltung

```sh
cap production nginx:site:enable    # Site aktivieren
cap production nginx:site:disable   # Site deaktivieren
cap production nginx:site:remove    # Config aus sites-available löschen
```

### Service-Steuerung

```sh
cap production nginx:service:start
cap production nginx:service:stop
cap production nginx:service:restart
cap production nginx:service:reload
cap production nginx:service:check_config   # nginx -t (Syntax prüfen)
cap production nginx:service:check_status   # systemctl status nginx
```

### Berechtigungen reparieren

```sh
cap production nginx:fix_folder_rights  # chmod o+x auf deploy_to + current_path (bei Permission-Errors)
```

---

## Deploy-Hook

Mit `nginx_hooks: true` (Standard) wird nach jedem `cap deploy` automatisch
`nginx:update` aufgerufen — Config wird hochgeladen und Nginx neu gestartet.
