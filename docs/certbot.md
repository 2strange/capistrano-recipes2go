# Capistrano Certbot — Let's Encrypt SSL

Let's Encrypt Zertifikate auf dem Server erstellen, erneuern und den Auto-Renew
einrichten — direkt per Capistrano, kein manuelles SSH nötig.

---

## Capfile

```ruby
require 'capistrano/recipes2go/certbot'
```

---

## Konfiguration

Alle Werte können in `config/deploy.rb` oder einer Stage-Datei gesetzt werden.

```ruby
set :certbot_roles,       -> { :web }       # Serverrolle für certbot-Tasks (beim Proxy-Setup: :proxy)
set :certbot_email,       -> { "" }         # E-Mail für Let's Encrypt (Pflicht bei generate)
set :certbot_domains,     -> { [...] }      # Domains — Standard: aus nginx_major_domain + nginx_domains abgeleitet
set :certbot_www_domains, -> { false }      # true: www.-Varianten automatisch mit einschließen
set :certbot_webroot,     -> { "#{current_path}/public" }  # Webroot für die HTTP-Challenge
set :certbot_path,        -> { "~" }        # Arbeitsverzeichnis auf dem Server
set :certbot_job_log,     -> { "#{shared_path}/log/lets_encrypt_cron.log" }  # Log für Cron-Modus
set :certbot_job_type,    -> { 'systemd' }  # Auto-Renew-Methode: 'systemd' (Standard) oder 'cron'
```

**Typisches Minimal-Setup:**

```ruby
set :certbot_email,   "mail@example.com"
set :certbot_roles,   [:proxy]          # beim proxy_nginx-Setup
set :certbot_webroot, "/var/www/html"   # Webroot auf dem Proxy-Server
```

---

## Tasks

### Zertifikat erstellen

```sh
cap production certbot:install   # certbot per apt installieren (einmalig)
cap production certbot:generate  # Zertifikat für die konfigurierten Domains anfordern
```

`certbot:generate` nutzt die Webroot-Challenge (nicht-interaktiv). Bei mehreren Domains
oder bereits vorhandenen Zertifikaten fragt die Task interaktiv nach `--expand`.

### Auto-Renew einrichten

```sh
cap production certbot:setup_auto_renew  # systemd-Timer oder cron-Job einrichten
```

- **systemd-Modus** (Standard): aktiviert `certbot.timer` (alle 12 Stunden) und richtet
  einen systemd-Override ein, der nach dem Renew automatisch Nginx neustartet.
- **Cron-Modus** (`set :certbot_job_type, 'cron'`): legt `/etc/cron.d/lets_encrypt` an
  (wöchentlich sonntags).

```sh
cap production certbot:auto_renew_logs    # Logs des Auto-Renew-Jobs anzeigen
cap production certbot:remove_auto_renew  # Auto-Renew-Job wieder entfernen
```

### Zertifikat prüfen und testen

```sh
cap production certbot:dry_renew  # Renew-Dry-Run (kein echtes Renew, nur Test)
cap production certbot:renew      # Zertifikat sofort erneuern
cap production certbot:check_tls  # TLS 1.3 für die Haupt-Domain prüfen
cap production certbot:delete     # Zertifikat löschen (fragt zur Sicherheit nach)
```

### DNS-Challenge (Wildcard-Zertifikate)

Für Domains, bei denen die HTTP-Challenge nicht möglich ist (z.B. Wildcard):

```sh
cap production certbot:dns_challenge_get       # interaktive SSH-Session: DNS-TXT-Eintrag anzeigen
cap production certbot:dns_challenge_validate  # nach DNS-Propagation: Zertifikat ausstellen
```

---

## Zusammenspiel mit Nginx

Das `certbot`-Recipe arbeitet eng mit `nginx` und `proxy_nginx` zusammen:

- `certbot_webroot` muss dem Nginx-`well-known`-Pfad entsprechen
- Nach dem Renew wird Nginx automatisch neugestartet (via systemd-Override)
- SSL-Zertifikatspfade für Nginx: `/etc/letsencrypt/live/<domain>/fullchain.pem`
  (werden in `nginx`/`proxy_nginx` als Default gesetzt)
