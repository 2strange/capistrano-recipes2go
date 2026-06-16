# Changelog — capistrano-recipes2go

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
