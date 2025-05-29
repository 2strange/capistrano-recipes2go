# 📦 Capistrano DB-Backup System

Dieses Capistrano-Setup ermöglicht automatisierte **Backups von PostgreSQL**, **Redis** und **YAML-Dumps** vor Deployments – lokal gespeichert und serverseitig aufgeräumt.

## 🔧 Setup & Konfiguration

### 1. `load:defaults` – Zentrale Settings

Diese Konfiguration wird automatisch geladen und kann in `config/deploy.rb` oder in einer Stage-Datei (`config/deploy/production.rb`) überschrieben werden:

```ruby
set :db_backup_yaml_on_deploy, true     # YAML-Backup aktivieren
set :db_backup_pg_on_deploy, true       # PostgreSQL-Backup aktivieren
set :db_backup_redis_on_deploy, false   # Redis-Backup deaktivieren (optional)

set :db_pg_pass, '...'                  # PostgreSQL-Passwort (besser mit ask verwenden)
set :db_redis_backup_namespace, 'cache' # Optionaler Redis-Namespace
```

---

## 🧩 Unterstützte Backup-Typen

### 🟡 YAML-Dump

* Führt `db:data:dump` aus
* Speichert `data.yml` als `.tar.gz` im `shared_path/backups`
* Lädt `.tar.gz` lokal herunter
* Bereinigt alte Backups (Standard: behalte 3)

```bash
cap production db:yaml_dumb
```

---

### 🔵 PostgreSQL Dump

* Führt `pg_dump` mit Kompression aus
* Lädt `.tar.gz` lokal herunter
* Bereinigt alte Dumps automatisch

```bash
cap production db:pg_dump
```

---

### 🔴 Redis Dump (mit TTLs)

* Läuft Ruby-Skript remote, um Redis-Inhalte + TTLs als JSON zu sichern
* Optionaler Namespace (`namespace:*`)
* Option: Entferne Namespace in JSON (`set :db_redis_remove_namespace, true`)
* Lädt `.tar.gz` lokal herunter
* Bereinigt alte Dumps

```bash
cap production db:redis_dump
```

---

## 🚀 Automatische Backups beim Deployment

```ruby
# In config/deploy.rb oder stage-File:
set :db_backup_yaml_on_deploy, true
set :db_backup_pg_on_deploy, true
set :db_backup_redis_on_deploy, false
```

→ Wird automatisch aufgerufen in:

```ruby
before 'deploy:starting', 'deploy:backup_database'
```

---

## 🔁 Daten zurückladen (YAML)

Warnung: **Überschreibt alle Daten** in der DB!

```bash
cap production db:upload_and_replace_data
```

Lädt `./db/data.yml` per `rsync` hoch und führt `db:data:load` aus.

---

## 📁 Verzeichnisstruktur

| Speicherort       | Zweck                  |
| ----------------- | ---------------------- |
| `shared/backups/` | Backups auf dem Server |
| `db/backups/`     | Lokale Kopien          |
| `shared/tmp/`     | Temporäre Ruby-Skripte |

---

## 🧹 Aufräum-Strategie

Alle Backups verwenden `ls | tail | rm`, um nur die letzten `n` Dateien zu behalten:

```ruby
set :db_keep_backups, 3  # global, kann pro Typ überschrieben werden
```

---

## ✅ Abhängigkeiten

### 🔸 PostgreSQL

* `pg_dump` muss auf dem Server installiert sein (und in PATH)

### 🔸 Redis-Backup

* Ruby + `redis`, `json`, `fileutils` Gems auf dem Server

### 🔸 YAML-Dump

* `db:seed`, `db:data:dump`, `db:data:load` Rake-Tasks müssen vorhanden sein (z. B. mit [seed\_dump](https://github.com/rroblak/seed_dump))

---

## ❗ Hinweise

* Verwende keine `db:data:load` ohne vorheriges Backup!
* `db_pg_pass` wird zur Laufzeit abgefragt, wenn nicht gesetzt
* Redis-Backup funktioniert **auch ohne SSH-Zugriff auf Redis** nur, wenn `redis-cli`/Ruby lokal darauf zugreifen können.

---

## 🔍 Beispiel-Ausführung

```bash
cap production deploy
# ruft automatisch:
# - db:yaml_dumb
# - db:pg_dump
# (je nach Konfiguration)
```
