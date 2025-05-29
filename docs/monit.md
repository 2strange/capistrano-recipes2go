# 🛡️ Capistrano + Monit Integration

Diese Capistrano-Erweiterung automatisiert die **Installation, Konfiguration und Steuerung von Monit** auf deinen Servern. Sie ermöglicht dir außerdem die **Integration mit einem Webclient**, Slack-Benachrichtigungen und optional auch Let's Encrypt Zertifikate für den Zugriff via HTTPS.

---

## 🔧 Grundkonfiguration

In `load:defaults` werden alle benötigten Variablen gesetzt, z. B.:

* `:monit_roles`: Zielrolle (z. B. `:web`)
* `:monit_app_processes`: Welche App-Prozesse sollen überwacht werden (z. B. `puma`, `sidekiq`)
* `:monit_system_processes`: Systemdienste (z. B. `nginx`, `postgresql`, `redis`)
* `:monit_webclient`: Domainname für das Monit-Webinterface (optional)

Weitere Konfigurationsoptionen beinhalten:

* Schwellenwerte für Load, CPU, RAM, HDD
* Prozess-spezifische Pfade (z. B. PID-Files)
* Mail-Versand bei Fehlern
* Slack-Webhooks
* m/Monit oder andere APIs

---

## 🧱 Grundlegende Tasks

| Task                       | Beschreibung                                                          |
| -------------------------- | --------------------------------------------------------------------- |
| `monit:install`            | Installiert Monit auf dem Server (wenn nötig)                         |
| `monit:setup`              | Läd alle Konfigurationsdateien hoch und aktiviert Webclient/Slack/API |
| `monit:start/stop/restart` | Steuert den Monit-Service                                             |
| `monit:syntax`             | Testet die Konfigurationssyntax                                       |
| `monit:reload`             | Läd Konfigurationen neu                                               |

---

## 🔁 Prozesssteuerung pro Dienst

Für jeden Dienst (z. B. `nginx`, `puma`, `sidekiq`) gibt es:

* `monit:task:nginx:start`
* `monit:task:sidekiq:restart`
* `monit:task:puma:configure` → Läd die entsprechende `monitrc` hoch

Es werden automatisch nur Prozesse behandelt, die in `:monit_processes` enthalten sind.

---

## 🌐 Monit WebClient

Falls aktiviert (`monit_webclient` gesetzt):

* Nginx-Konfiguration wird hochgeladen (`nginx:monit:add`)
* Webclient aktiviert (`nginx:monit:enable`)
* Optionale SSL-Verschlüsselung via Let's Encrypt (`monit_webclient_ssl: true`)

---

## 🔒 Let's Encrypt / Certbot

Zwei Wege stehen zur Verfügung:

| Task                          | Funktion                                        |
| ----------------------------- | ----------------------------------------------- |
| `certbot:monit_cert`          | Nicht-interaktive Webroot-Zertifikatserstellung |
| `certbot:monit_dns_challenge` | Interaktive DNS-Challenge per SSH-Sitzung       |

---

## 📣 Slack Integration

Wenn `monit_use_slack` = `true`:

* Task `slack:configure_monit` läd das `alert_slack.sh` Skript hoch
* Slack-Webhooks werden bei Events ausgelöst (sofern korrekt konfiguriert)

---

## 🧠 Weitere Checks

Die folgenden Check-Typen lassen sich konfigurieren:

| Kategorie                               | Variable                   |
| --------------------------------------- | -------------------------- |
| Websites (z. B. 200 OK auf `/status`)   | `:monit_websites_to_check` |
| TCP Hosts (z. B. Redis, PostgreSQL)     | `:monit_hosts_to_check`    |
| Dateien (z. B. Logrotation)             | `:monit_files_to_check`    |
| Ordner (z. B. Größe von `/tmp/uploads`) | `:monit_folders_to_check`  |

---

## 🪝 Deploy-Hooks

* **Vor dem Deployment:** Stoppt Prozessüberwachung (`unmonitor`)
* **Während des Deployments:** Aktiviert Webclient (falls nötig)
* **Nach dem Deployment:** Startet Prozessüberwachung wieder (`monitor`)

---

## 💡 Beispiel: Monit WebClient aktivieren

1. Setze in `deploy.rb`:

   ```ruby
   set :monit_webclient, "monit.example.com"
   set :monit_webclient_ssl, true
   set :monit_use_slack, true
   ```
2. Starte:

   ```bash
   cap production monit:install
   cap production monit:setup
   ```
3. Falls nötig:

   ```bash
   cap production certbot:monit_cert
   ```

---

## 📁 Struktur & Templates

* Die Konfigurationsdateien werden über `template2go` hochgeladen (z. B. `monitrc`, `alert_slack.sh`, Nginx-Config).
* Templates befinden sich in deinem `recipes2go`-Verzeichnis und lassen sich pro Projekt anpassen.

---

## ✅ Best Practices

* Nutze `monit_processes` gezielt und schlank.
* Vermeide `monit_webclient_ssl: true` ohne ein gültiges Zertifikat.
* Starte `cap monit:setup` **nach** dem ersten erfolgreichen Deployment.
* Verwende `monit_event_api_url` **nur**, wenn du ein M/Monit-Backend hast oder eigene Alerts via HTTP verarbeiten möchtest.

