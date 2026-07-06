# Changelog — capistrano-recipes2go

## 0.8.0 — (unreleased, PR feat/instance-env-g1-g2)

**Multi-Instanz-Stages: Service-Env vom Stage-Namen entkoppelt + generische Unit-Env-Vars.**
Rückwärtskompatibel: bestehende Stages (rails_env == stage bzw. ohne rails_env) rendern
byte-identisch; ohne gesetzte `*_env_vars` entstehen keine neuen Zeilen.

- **feat (G1, Service-Env):** `puma_config.erb` nutzt `fetch(:puma_env, fetch(:rails_env,
  fetch(:stage)))` statt hart `fetch(:stage)`; sidekiq analog via `:sidekiq_env`
  (`--environment`). Eine Instanz-Stage (z.B. `spital` mit `rails_env=production`)
  bootet ihre Services damit korrekt als production.
- **feat (G2, Unit-Env):** `set :puma_env_vars, {}` / `set :sidekiq_env_vars, {}` werden
  als `Environment="KEY=VAL"`-Zeilen in `puma_service.erb`/`sidekiq_service.erb` gerendert —
  Instanz-Variablen (z.B. `SLOTS_INSTANCE`) erreichen die LAUFENDEN systemd-Services
  (`set :default_env` gilt nur für Deploy-`execute`).
- **fix (G3, db.rake):** `db:seed`/`db:data:dump`/`db:data:load` nutzen
  `RAILS_ENV=#{fetch(:rails_env, fetch(:stage))}` (Muster wie `:pg_rails_env`) statt
  hart den Stage-Namen.
- Defaults deklariert in `puma.rake`/`sidekiq.rake`; Render-Beweis beidseitig im
  PR-Text (Legacy byte-identisch / Instanz production + Env-Injektion).


## 0.7.16 — 2026-06-16

**Setup macht jetzt SSL + Dienste mit — „nach `cap <stage> setup` einfach deployen".**
Rein additiv; bestehende Tasks/Templates/Defaults und `server:setup` unverändert.

- **feat (Let's Encrypt im Setup):** neues Mini-Template `nginx_letsencrypt.conf.erb` +
  Task `certbot:bootstrap`. Lädt einen **minimalen ACME-only `:80`-vhost** hoch
  (nur `.well-known/acme-challenge` → `:certbot_webroot`, **kein** Upstream/SSL/
  Container-Bezug), zieht das Cert (`certbot:generate`) und entfernt den vhost
  wieder. Damit steht das Zertifikat **vor** dem ersten Deploy — kein Flag-Toggle-
  Dance mehr, kein „Proxy wegfeuern" durch eine SSL-Config ohne Cert. Läuft auf
  `:certbot_roles` (im Proxy-Setup `[:proxy]`).
- **feat (Setup-Aggregat erweitert):** `cap <stage> setup` ruft jetzt zusätzlich:
  - `certbot:bootstrap` (wenn `:nginx_use_ssl`),
  - `puma:configure` statt nur `puma:setup` (Service-Upload **+ enable**),
  - `sidekiq:configure` (wenn `:sidekiq_default_hooks`).
- **chore:** `certbot.rake` lädt jetzt explizit `base_helpers` + `nginx_helpers`
  (für `template2go`/Domain-Helper im neuen Task).

> Nutzung unverändert pro App in `config/deploy/<stage>.rb`, z.B.:
> `set :nginx_use_ssl, true` · `set :certbot_email, "…"` ·
> `set :certbot_roles, [:proxy]` · `set :certbot_webroot, "/var/www/html"`.
