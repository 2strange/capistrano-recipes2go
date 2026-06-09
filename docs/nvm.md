# Capistrano NVM — Node Version Manager

NVM (Node Version Manager) auf dem Server installieren und die gewünschte
Node.js-Version verwalten. Wird benötigt, wenn Rails-Assets mit Node.js gebaut
werden oder Nuxt-Assets auf dem App-Server kompiliert werden sollen.

---

## Capfile

```ruby
require 'capistrano/recipes2go/nvm'
```

---

## Konfiguration

```ruby
set :nvm_roles,        -> { :app }          # Serverrolle für NVM-Tasks
set :nvm_install_path, -> { "$HOME/.nvm" }  # Installationspfad von NVM
set :nvm_version,      -> { 'v0.39.7' }     # NVM-Version (bei Bedarf aktualisieren)
set :nvm_node_version, -> { '23' }          # Node.js-Version, die installiert werden soll
```

---

## Tasks

### NVM und Node.js installieren

```sh
cap production nvm:install       # NVM installieren (falls noch nicht vorhanden)
cap production nvm:install_node  # Node.js in der konfigurierten Version installieren
cap production nvm:use           # Node.js-Version als default setzen
```

`nvm:install` ist idempotent — läuft es durch, wenn NVM bereits installiert ist.

`nvm:install` schreibt den NVM-Init-Block **an den Anfang** von `.bashrc`, damit
er auch in nicht-interaktiven Capistrano-Sessions verfügbar ist.

### Installierte Versionen prüfen

```sh
cap production nvm:list_installed   # Alle installierten Node.js-Versionen anzeigen
cap production nvm:list_available   # Alle verfügbaren Node.js-Versionen anzeigen
```

---

## Hinweise

- NVM ist **nicht** in den globalen `setup`-Task eingehängt, um mehrfaches
  Ausführen zu vermeiden. Manuell aufrufen.
- Der `server`-Recipe (`capistrano/recipes2go/server`) enthält NVM-Installation
  bereits als Teil des Server-Setups (`srvr_install_nvm: true`). Wer `server:setup`
  nutzt, braucht `nvm:install` nicht separat.
- Capistrano-Sessions sind non-interaktiv — deshalb muss NVM im oberen Teil von
  `.bashrc` stehen (NVM-Init-Block), was `nvm:install` automatisch erledigt.
