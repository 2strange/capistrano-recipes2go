
# Capistrano Nginx Proxy/App Setup

Dieses Capistrano-Rezept ermöglicht die Bereitstellung und Verwaltung einer Nginx-Infrastruktur, die in einen **Proxy-Server** und einen oder mehrere **App-Server** unterteilt ist. Dieses Setup ist ideal für Umgebungen wie Proxmox, Docker oder Cloud-VPS, wo eine klare Trennung zwischen dem öffentlichen Zugangspunkt und den Anwendungs-Workern gewünscht ist.

## Inhaltsverzeichnis

1.  [Überblick](#überblick)
2.  [Voraussetzungen](#voraussetzungen)
3.  [Installation](#installation)
4.  [Konfiguration](#konfiguration)
    *   [Rollen](#rollen)
    *   [Proxy-Server-Einstellungen](#proxy-server-einstellungen)
    *   [App-Server-Einstellungen](#app-server-einstellungen)
    *   [Proxy-Caching-Einstellungen](#proxy-caching-einstellungen)
    *   [Linked Directories](#linked-directories)
5.  [Nginx Templates](#nginx-templates)
6.  [Nutzung](#nutzung)
    *   [Erstes Setup](#erstes-setup)
    *   [Reguläre Deployments](#reguläre-deployments)
    *   [Manuelle Nginx-Verwaltung](#manuelle-nginx-verwaltung)
7.  [Wichtige Hinweise](#wichtige-hinweise)
8.  [Beispiel-Verbindungen](#beispiel-verbindungen)

## 1. Überblick

Dieses Rezept teilt die Nginx-Verantwortlichkeiten wie folgt auf:

*   **Proxy-Server (Öffentlich):**
    *   Hört auf Port 80 (HTTP) und 443 (HTTPS).
    *   Behandelt alle Domains und SSL-Terminierung (Zertifikate, HSTS).
    *   Leitet HTTP auf HTTPS um und ältere Domains auf die Hauptdomain.
    *   Validiert Certbot-Anfragen (`.well-known`).
    *   Leitet alle bereinigten Anfragen an den **internen Nginx App Server** weiter (z.B. auf Port 4550).
    *   Hat eigene Access/Error Logs.
*   **App-Server (Intern):**
    *   Hört auf einem internen, nicht-öffentlichen Port (z.B. 4550), der nur vom Proxy-Server erreichbar ist.
    *   Serviert statische Assets der Rails/Nuxt-App (z.B. `/assets/`, `public`/`dist` Root).
    *   Behandelt Rails- und Medien-Caching.
    *   Leitet Anfragen an die eigentlichen App-Prozesse (Puma/Thin) weiter.
    *   Hat eigene Access/Error Logs.
    *   Definiert `client_max_body_size`, `keepalive_timeout` und `error_page`.

## 2. Voraussetzungen

*   Capistrano 3.x+
*   Nginx installiert auf den Servern, die die `:proxy` und `:app` Rollen erhalten.
*   SSH-Zugang für Capistrano mit entsprechenden `sudo`-Rechten für Nginx-Konfigurationsdateien und Dienstverwaltung.
*   Verständnis von Capistrano-Rollen und der Konfiguration von Deployments.
*   Grundkenntnisse von Nginx-Konfigurationen.

## 3. Installation

1.  Stelle sicher, dass die Hilfsmodule `capistrano/nuxt2/base_helpers` und `capistrano/nuxt2/nginx_helpers` (oder deren Äquivalente in deinem Setup) verfügbar sind.
2.  Lege die bereitgestellte Capistrano-Task-Datei (z.B. `lib/capistrano/tasks/nginx.rake`) in deinem Projekt ab.
3.  Füge in deiner `Capfile` diese Zeile hinzu:

    ```ruby
    # Capfile
    require 'capistrano/recipes2go/proxy_nginx'
    ```

## 4. Konfiguration

Alle relevanten Einstellungen werden in deiner Capistrano-Konfiguration (z.B. `config/deploy.rb` oder `config/deploy/<stage>.rb`) vorgenommen.

### Rollen

Definiere die Rollen für deine Server. Ein Server kann auch beide Rollen haben, wenn er sowohl Proxy als auch App-Server ist (nicht empfohlen für Produktion).

```ruby
# config/deploy/<stage>.rb
server 'your_proxy_server_ip', user: 'deploy_user', roles: %w{proxy}
server 'your_app_server_ip',   user: 'deploy_user', roles: %w{app}

# Wenn du mehrere App-Server hast:
# server 'your_app_server_ip_2', user: 'deploy_user', roles: %w{app}
```

### Proxy-Server-Einstellungen

Diese Einstellungen gelten für den öffentlichen Nginx-Server.

```ruby
# config/deploy.rb oder config/deploy/<stage>.rb
set :nginx_proxy_roles,       -> { :proxy } # Rollen, die als Proxy fungieren
set :nginx_proxy_template,    -> { :default } # Name des Templates (nginx_proxy_conf.erb)
set :nginx_proxy_site_name,   -> { "#{fetch(:application)}_#{fetch(:stage)}_proxy" }

set :nginx_domains,           -> { ["example.com", "www.example.com"] } # Alle Domains
set :nginx_major_domain,      -> { "example.com" } # Hauptdomain für Umleitungen
set :nginx_remove_www,        -> { true } # true für Umleitung von www. auf non-www.
set :nginx_use_ssl,           -> { true } # SSL/HTTPS aktivieren
set :nginx_also_allow_http,   -> { false } # false: HTTP wird auf HTTPS umgeleitet; true: HTTP ist auch direkt erlaubt (nicht empfohlen)

# SSL-Zertifikatspfade (standardmäßig für Let's Encrypt)
set :nginx_ssl_cert,          -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" }
set :nginx_ssl_key,           -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" }
set :nginx_other_ssl_cert,    -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" } # Für alte Domains
set :nginx_other_ssl_key,     -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" } # Für alte Domains

set :nginx_strict_security,   -> { fetch(:nginx_use_ssl, false) } # HSTS-Header aktivieren
set :nginx_ssl_ciphers,       -> { "TLS_AES_128_GCM_SHA256:..." } # Empfohlene Cipher-Suites

set :allow_well_known_proxy,  -> { true } # .well-known (Certbot) auf dem Proxy erlauben
set :nginx_proxy_well_known_root, -> { "/var/www/html" } # Pfad für Certbot-Validierung
set :nginx_proxy_log_folder,  -> { "/var/log/nginx" } # Log-Ordner auf dem Proxy

set :nginx_proxy_hooks,       -> { true } # Deploy-Hooks für Proxy Nginx aktivieren

# WICHTIG: Die IP-Adresse und der Port des internen App-Nginx-Servers
set :nginx_upstream_app_host, -> { '10.0.0.5' } # Ersetzen durch die interne IP des App-Servers
set :nginx_upstream_app_port, -> { 4550 } # Port, auf dem der App-Nginx lauscht
```

### App-Server-Einstellungen

Diese Einstellungen gelten für den internen Nginx-Server, der die Rails-/Nuxt-Anwendung bedient.

```ruby
# config/deploy.rb oder config/deploy/<stage>.rb
set :nginx_app_roles,         -> { :app } # Rollen, die als App-Server fungieren
set :nginx_app_template,      -> { :default } # Name des Templates (nginx_app_conf.erb)
set :nginx_app_site_name,     -> { "#{fetch(:application)}_#{fetch(:stage)}_app" }

# Pfad zu den statischen Dateien der Anwendung (Rails public, Nuxt .output/public oder dist)
set :nginx_static_dir,        -> { "#{current_path}/public" } # Für Rails-Apps

# App-Server-Prozess-Einstellungen
set :app_instances,           -> { 1 } # Anzahl der Rails/Nuxt-Instanzen
set :rails_app_server,        -> { :puma }  # Welcher App-Server wird verwendet (:puma oder :thin)

set :nginx_log_folder,        -> { "log" } # Log-Ordner relativ zu shared_path
set :nginx_app_hooks,         -> { true } # Deploy-Hooks für App Nginx aktivieren
set :allow_well_known_app,    -> { false } # .well-known auf dem App-Server (normalerweise nur auf Proxy)
```

### Proxy-Caching-Einstellungen

Konfiguriert den Nginx-Proxy-Cache auf dem App-Server für Rails-Aktionen und Medien.

```ruby
# config/deploy.rb oder config/deploy/<stage>.rb
# Cache Rails
set :proxy_cache_rails,           -> { true } # true zum Aktivieren
set :proxy_cache_rails_directory, -> { "#{shared_path}/tmp/proxy_cache/rails" }
set :proxy_cache_rails_levels,    -> { "1:2" }
set :proxy_cache_rails_name,      -> { "RAILS_#{fetch(:application)}_#{fetch(:stage)}_CACHE" }
set :proxy_cache_rails_size,      -> { "4m" } # Keys Zone Size
set :proxy_cache_rails_time,      -> { "24h" } # Inactive time
set :proxy_cache_rails_max,       -> { "1g" } # Max cache size
set :proxy_cache_rails_200,       -> { "60m" } # Cache valid for 200/302 responses
set :proxy_cache_rails_404,       -> { "10m" } # Cache valid for 404 responses
set :proxy_cache_rails_stale,     -> { ["error", "timeout", "invalid_header", "updating"] }

# Cache Media (z.B. Dragonfly, Paperclip)
set :proxy_cache_media,           -> { true } # true zum Aktivieren
set :proxy_cache_media_path,      -> { "media" } # URL-Pfad für Medien (z.B. /media/images)
set :proxy_cache_media_directory, -> { "#{shared_path}/tmp/proxy_cache/media" }
set :proxy_cache_media_levels,    -> { "1:2" }
set :proxy_cache_media_name,      -> { "MEDIA_#{fetch(:application)}_#{fetch(:stage)}_CACHE" }
set :proxy_cache_media_size,      -> { "2m" }
set :proxy_cache_media_time,      -> { "48h" }
set :proxy_cache_media_max,       -> { "1g" }
```


## 5. Nginx Templates

Dieses Rezept erwartet zwei Nginx-Template-Dateien in deinem Capistrano `templates/`-Verzeichnis (z.B. `config/deploy/templates/`):

*   `nginx_proxy_conf.erb`: Die Konfiguration für den Nginx Proxy-Server.
*   `nginx_app_conf.erb`: Die Konfiguration für den Nginx App-Server.

Du solltest die von dir bereitgestellten und angepassten `.erb`-Dateien in dieses Verzeichnis legen.

## 6. Nutzung

### Erstes Setup

Führe diese Tasks aus, um Nginx zum ersten Mal auf den Servern einzurichten und zu aktivieren.

```bash
# Setzt beide Nginx-Konfigurationen auf den jeweiligen Servern auf und lädt sie hoch
cap <stage> nginx:setup_all

# Optional: Aktiviere die Seiten manuell, falls du nginx:setup_all nicht verwendest
# cap <stage> nginx:proxy:site:enable
# cap <stage> nginx:app:site:enable
```

### Reguläre Deployments

Wenn du ein Deployment durchführst, werden die Nginx-Konfigurationen automatisch aktualisiert und die Nginx-Dienste neu geladen/gestartet, dank der Deploy-Hooks.

```bash
cap <stage> deploy
```

### Manuelle Nginx-Verwaltung

Du kannst Nginx-Dienste auch manuell steuern oder überprüfen:

*   **Upload der Konfigurationen:**
    ```bash
    cap <stage> nginx:proxy:site:upload
    cap <stage> nginx:app:site:upload
    ```
*   **Aktivieren/Deaktivieren der Sites:**
    ```bash
    cap <stage> nginx:proxy:site:enable
    cap <stage> nginx:proxy:site:disable
    cap <stage> nginx:app:site:enable
    cap <stage> nginx:app:site:disable
    ```
*   **Neustart/Reload des Dienstes:**
    ```bash
    cap <stage> nginx:proxy:service:restart # oder :reload
    cap <stage> nginx:app:service:restart   # oder :reload
    ```
*   **Konfiguration prüfen:**
    ```bash
    cap <stage> nginx:proxy:service:check_config
    cap <stage> nginx:app:service:check_config
    ```
*   **Status prüfen:**
    ```bash
    cap <stage> nginx:proxy:service:check_status
    cap <stage> nginx:app:service:check_status
    ```
*   **Ordnerrechte auf dem App-Server korrigieren (falls Nginx-Fehler auftreten):**
    ```bash
    cap <stage> nginx:app:fix_folder_rights
    ```

## 7. Wichtige Hinweise

*   **Firewall:** Stelle sicher, dass die Firewalls korrekt konfiguriert sind:
    *   **Proxy-Server:** Port 80 (HTTP) und 443 (HTTPS) müssen öffentlich zugänglich sein.
    *   **App-Server:** Nur der `nginx_upstream_app_port` (z.B. 4550) muss vom Proxy-Server aus erreichbar sein. Alle anderen Ports sollten für externe Zugriffe geschlossen sein.
*   **Interne Netzwerke:** Nutze für `nginx_upstream_app_host` eine private/interne IP-Adresse des App-Servers, um den Netzwerkverkehr zu isolieren und zu optimieren.
*   **`cert_domain` Variable:** Stelle sicher, dass die Variable `cert_domain` in deinem Capistrano-Setup definiert ist, da sie für die SSL-Zertifikatspfade verwendet wird. (oft `set :cert_domain, -> { fetch(:nginx_major_domain) || fetch(:nginx_domains).first }`)

## 8. Beispiel-Verbindungen

```
             Internet
                |
                | (HTTP/S auf Port 80/443)
                V
          +-----------------+
          | Nginx Proxy     |
          | (Public IP)     |
          | - SSL-Terminierung
          | - Domain-Redirects
          | - Certbot
          +-----------------+
                |
                | (Interne IP:Port, z.B. 10.0.0.5:4550)
                V
          +-----------------+
          | Nginx App Server|
          | (Private IP)    |
          | - Statische Dateien
          | - Rails/Media Cache
          | - Anfragen an Puma/Thin
          +-----------------+
                |
                | (Unix Sockets)
                V
          +-----------------+
          | Puma/Thin       |
          | (App-Prozesse)  |
          +-----------------+
```