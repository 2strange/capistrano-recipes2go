# Capistrano Dragonfly — Attachment-Sync

Dragonfly-Attachment-Ordner per rsync zwischen lokalem Rechner und Server
hoch- bzw. runterladen. Nützlich bei Migrations, Staging-Setups oder als
manuelles Backup der Upload-Dateien.

---

## Capfile

```ruby
require 'capistrano/recipes2go/dragonfly'
```

---

## Konfiguration

```ruby
set :backup_attachment_roles,       -> { :app }
set :backup_attachment_name,        -> { 'dragonfly' }                             # Name für lokalen Backup-Ordner
set :backup_attachment_user,        -> { fetch(:user, 'deploy') }                  # SSH-User für rsync
set :backup_attachment_host,        -> { roles(:app).first.hostname }              # Server-Hostname
set :backup_attachment_remote_path, -> { "#{shared_path}/public/system/dragonfly/live" }  # Pfad auf dem Server
set :backup_attachment_local_path,  -> { "backups/dragonfly/#{fetch(:stage)}" }   # Lokaler Zielpfad
```

Der `rsync`-Pfad `backup_attachment_rsync_path` wird automatisch aus User, Host
und Remote-Pfad zusammengesetzt.

---

## Tasks

### Attachments herunterladen (Server → lokal)

```sh
cap production dragonfly:get_attachments
```

Rsync vom Server in `backups/dragonfly/production/` lokal. Löscht lokal
Dateien, die auf dem Server nicht mehr existieren (`--delete`).

### Attachments hochladen (lokal → Server)

```sh
cap production dragonfly:push_attachment
```

Rsync vom lokalen Backup-Ordner auf den Server. Löscht auf dem Server
Dateien, die lokal nicht mehr existieren (`--delete`).

---

## Beispiel: Staging mit Produktions-Daten befüllen

```sh
# 1. Von Produktion herunterladen:
cap production dragonfly:get_attachments
# Dateien liegen jetzt in backups/dragonfly/production/

# 2. Lokal den Pfad für Staging anpassen (manuell umbenennen oder set:backup_attachment_local_path überschreiben)

# 3. Auf Staging hochladen:
cap staging dragonfly:push_attachment
```

---

## Hinweise

- `rsync` muss lokal und auf dem Server installiert sein.
- SSH-Zugang mit dem konfigurierten User muss ohne Passwort funktionieren (Deploy-Key).
- `--delete` ist aktiv: fehlende Dateien auf der Gegenseite werden gelöscht. Vor dem
  Hochladen sicherstellen, dass der lokale Ordner vollständig ist.
