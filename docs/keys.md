# Capistrano Keys — Rails Credentials & Config-Sync

Rails `master.key`, `credentials.yml.enc` und eine optionale `configuration.yml`
per rsync auf den Server synchronisieren. Diese Dateien liegen in
`shared/config/` und werden von Capistrano als `linked_files` verknüpft.

---

## Capfile

```ruby
require 'capistrano/recipes2go/keys'
```

---

## Konfiguration

```ruby
set :keys_use_configuration, -> { false }  # true: configuration.yml ebenfalls synct + verlinkt
```

Per Default werden `config/master.key` und `config/credentials.yml.enc` als
`linked_files` eingetragen. Mit `keys_use_configuration: true` kommt
`config/configuration.yml` hinzu.

---

## Tasks

### Einmaliges Setup (empfohlen vor erstem Deploy)

```sh
cap production keys:setup
```

Lädt `master.key` + `credentials.yml.enc` hoch (und `configuration.yml`, falls
`keys_use_configuration` aktiv).

### Einzelne Dateien hochladen

```sh
cap production keys:upload_master   # master.key + credentials.yml.enc
cap production keys:upload_config   # configuration.yml (nur wenn keys_use_configuration true)
```

### Prüfen

```sh
cap production keys:check_keys    # Warnt, wenn eine der Dateien fehlt oder leer ist
cap production keys:check_config  # Listet den Inhalt von shared/config/ auf dem Server
```

---

## Automatischer Update bei jedem Deploy

Ist `keys_use_configuration: true`, wird `configuration.yml` bei jedem
`cap deploy` automatisch vor dem Start hochgeladen (via `before 'deploy:starting'`-Hook).

---

## Hinweise

- Die Dateien liegen lokal unter `./config/` und werden nach `shared/config/`
  auf dem Server syncronisiert.
- `master.key` darf **nicht** ins Git-Repository — in `.gitignore` eintragen.
- `rsync` wird für den Upload verwendet (lokale CLI, nicht Capistrano-intern).
- Rollen: `app`, `db` und `web` erhalten alle die Keys.
