# Capistrano PostgreSQL — DB-Setup

PostgreSQL-Datenbank und -User anlegen, `database.yml` generieren und auf
den Server übertragen. Abgeleitet aus dem nicht mehr gepflegten
`capistrano-postgresql`-Gem.

---

## Capfile

```ruby
require 'capistrano/recipes2go/postgresql'
```

`database.yml` wird automatisch zu `linked_files` hinzugefügt.

---

## Konfiguration

```ruby
set :pg_rails_env,          -> { fetch(:rails_env) || fetch(:stage) }
set :pg_database,           -> { "#{fetch(:application)}_#{fetch(:stage)}" }  # Datenbankname
set :pg_username,           -> { fetch(:pg_database) }                         # DB-User (Standard = DB-Name)
set :pg_password,           -> { pg_password_generate }                        # Auto-generiertes Passwort
set :pg_host,               -> { 'localhost' }      # Bei Multi-Server: primärer :db-Host
set :pg_port,               5432
set :pg_pool,               13
set :pg_timeout,            5000                    # ms (Rails-Default)
set :pg_encoding,           'unicode'

# PostgreSQL-System-Settings
set :pg_skip_sudo,          false
set :pg_system_user,        'postgres'              # System-PG-User
set :pg_system_db,          'postgres'              # System-DB für Admin-Queries
set :pg_use_hstore,         false                   # hstore-Extension aktivieren
set :pg_extensions,         []                      # Weitere PG-Extensions, z.B. ['uuid-ossp']
set :pg_disable_gssencmode, false                   # true: bei GSSAPI-Problemen

set :pg_templates_path,     'config/deploy/templates'  # Pfad für eigene database.yml.erb
```

---

## Tasks

### Vollständiges Setup (empfohlen)

```sh
cap production postgresql:setup
```

Führt der Reihe nach aus:
1. DB-User anlegen (oder Passwort aktualisieren, falls abweichend)
2. Datenbank anlegen (falls nicht vorhanden)
3. Extensions installieren
4. `database.yml`-Archetype generieren
5. `database.yml` auf alle App-Server verteilen

### Einzelne Tasks

```sh
cap production postgresql:create_database_user   # User anlegen / Passwort aktualisieren
cap production postgresql:create_database         # Datenbank anlegen
cap production postgresql:add_extensions          # pg_extensions installieren
cap production postgresql:generate_database_yml_archetype  # Archetype auf primärem DB-Server generieren
cap production postgresql:generate_database_yml   # Archetype auf alle App-Server kopieren
```

### Aufräumen

```sh
cap production postgresql:remove_all        # DB + User + Extensions löschen
cap production postgresql:remove_extensions # Nur Extensions entfernen
```

---

## Hinweise

- Das Passwort wird beim ersten Setup automatisch generiert und im `database.yml`-
  Archetype auf dem Server gespeichert. Bei nachfolgenden Deploys wird es aus dem
  Archetype gelesen — kein Passwort im lokalen Repo.
- Für eigene `database.yml.erb`-Templates den Pfad `pg_templates_path` anpassen.
- `linked_files` enthält nach dem `require` automatisch `config/database.yml`.
