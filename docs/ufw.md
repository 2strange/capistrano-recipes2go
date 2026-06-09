# Capistrano UFW — Uncomplicated Firewall

UFW-Firewall auf dem Server einrichten: SSH, HTTP und HTTPS öffnen, weitere
Ports konfigurieren und die Firewall aktivieren.

---

## Capfile

```ruby
require 'capistrano/recipes2go/ufw'
```

---

## Konfiguration

```ruby
set :ufw_ssh_port,         -> { 22 }   # SSH-Port (anpassen, falls nicht Standard)
set :ufw_additional_ports, -> { [] }   # Weitere Ports, z.B. [2224, 8080]
```

UFW wird immer auf der `:web`-Rolle ausgeführt (hardcoded, nicht konfigurierbar).

---

## Tasks

### Setup

```sh
cap production ufw:install  # UFW per apt installieren (falls nicht vorhanden)
cap production ufw:setup    # Regeln konfigurieren und Firewall aktivieren
```

`ufw:setup`:
1. Reset (alle bestehenden Regeln löschen)
2. Default: incoming deny, outgoing allow
3. SSH-Port öffnen (`:ufw_ssh_port`)
4. Port 80 (HTTP) und 443 (HTTPS) öffnen
5. Zusätzliche Ports aus `:ufw_additional_ports` öffnen
6. UFW aktivieren

### Prüfen und Verwalten

```sh
cap production ufw:status  # UFW-Status und aktive Regeln anzeigen (ufw status verbose)
cap production ufw:rules   # Alle hinzugefügten Regeln anzeigen (ufw show added)
cap production ufw:disable # UFW deaktivieren
```

---

## Hinweise

- Der `server`-Recipe (`capistrano/recipes2go/server`) enthält UFW ebenfalls als
  Teil des Server-Setups (`set :srvr_enable_firewall, true`). Wer `server:setup`
  nutzt, braucht `ufw:setup` nicht separat.
- Nach dem Reset gehen alle bisherigen Regeln verloren — immer sicherstellen, dass
  SSH geöffnet ist, bevor `ufw:setup` ausgeführt wird.
- Bei mehreren Servern (Proxy + App): UFW auf beiden separat konfigurieren.
  Auf dem App-Server sollte der interne Nginx-Port (z.B. 4550) für die Proxy-IP
  freigegeben werden, nicht öffentlich.
