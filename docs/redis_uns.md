# 🧠 Capistrano Redis Namespace Migration (Sidekiq 7+)

Diese Tasks helfen dir, Redis-Keys zwischen Datenbanken zu verschieben, insbesondere für Migrationszwecke im Kontext von **Sidekiq 7+**, wo Namespaces abgeschafft wurden. Du kannst damit:

* Redis-Keys aus einem Namespace in eine neue Datenbank ohne Namespace kopieren
* Kandidaten anzeigen, ohne Änderungen vorzunehmen
* Redis-Datenbanken analysieren (Key-Zählung, Auflistung)
* alles direkt per Capistrano und auf dem Server ausführen

---

## ⚙️ Konfiguration

In deiner `config/deploy.rb` oder `deploy/STAGE.rb` kannst du folgende Variablen setzen:

| Variable               | Beschreibung                                                              |
| ---------------------- | ------------------------------------------------------------------------- |
| `:redis_uns_namespace` | Der aktuelle Namespace, z. B. `sl_sidekiq`                                |
| `:redis_uns_old_redis` | Hash mit Redis-Konfiguration der alten DB (z. B. `{ db: 0 }`)             |
| `:redis_uns_new_redis` | Hash mit Redis-Konfiguration der Ziel-DB (z. B. `{ db: 1, host: "..." }`) |
| `:redis_uns_roles`     | Serverrolle, auf der Redis-Skripte ausgeführt werden (z. B. `:web`)       |

---

## 📦 `redis_uns:upload_namespace_script`

Lädt alle Redis-Helferskripte (`copy_uns.rb`, `list_candidates.rb`, `count_all.rb`, `list_all.rb`) auf den Zielserver in den Ordner `shared_path/upgrade_helpers`.

✅ **Einmal vor der Nutzung der anderen Tasks ausführen.**

---

## 🧾 Redis-Analyse-Tasks

### `redis_uns:count_all_old` / `redis_uns:count_all_new`

Zählt alle Keys in jeder Redis-Datenbank (0–15) der alten bzw. neuen Redis-Konfiguration. Ideal, um die Auslastung und Verteilung zu prüfen, **ohne Inhalte zu laden**.

### `redis_uns:list_all_old` / `redis_uns:list_all_new`

Listet alle Keys (inkl. Typ und TTL) jeder Redis-Datenbank auf. **Vorsicht bei großen Datenmengen!**

---

## 🔍 Analyse des Namespaces

### `redis_uns:list_candidates`

Listet alle Keys im definierten Namespace in der Quell-Redis-Datenbank auf. Zeigt an, wie die Keys nach der Migration aussehen würden.
➡️ Diese Task **verändert nichts**, sondern dient der Vorprüfung.

---

## 🔁 Migration durchführen

### `redis_uns:copy_uns`

Kopiert alle Keys mit dem gesetzten Namespace (`NAMESPACE:*`) aus der alten Redis-Instanz in die neue Redis-Instanz **ohne Namespace**. Dabei bleiben TTL und Typ erhalten.

> ⚠️ Die Keys in der Ziel-DB werden **überschrieben**, falls vorhanden.

---

## 🧼 Sicherheit & Debugging

* Alle Tasks setzen intern Umgebungsvariablen (`REDIS_NAMESPACE`, `REDIS_SOURCE_CONFIG`, `REDIS_TARGET_CONFIG`), um Skripte mit verschiedenen Redis-Instanzen und Konfigurationen zu nutzen.
* Fehlerhafte Konfigurationen (z. B. kein Hash bei `redis_uns_old_redis`) führen zu klaren Fehlermeldungen.
* Redis-Skripte bleiben auf dem Server im Ordner `shared/upgrade_helpers`.

---

## 📑 Empfehlung: Vorgehensweise

1. `cap STAGE redis_uns:upload_namespace_script`
2. `cap STAGE redis_uns:list_candidates` – prüfen!
3. `cap STAGE redis_uns:copy_uns` – migrieren
4. `cap STAGE redis_uns:count_all_old` / `list_all_old` – Verbleib prüfen
5. `cap STAGE redis_uns:count_all_new` – Erfolg prüfen