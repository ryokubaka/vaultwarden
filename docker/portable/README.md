# Vaultwarden portable pack (1A / 2A)

Lift-and-shift stack for pilot / on-site demo.

| Service | Role |
|---------|------|
| **vaultwarden** | Bitwarden-compatible server (`1.37.1`) |
| **caddy** | HTTPS reverse proxy, local CA (`2.11.4`) |
| **mailpit** | Optional (`--profile mailpit`) catch-all UI |
| **backup** | Optional (`--profile backup`) → NAS via [offen/docker-volume-backup](https://github.com/offen/docker-volume-backup) |

Default vault URL: `https://vw.org-testing.meow`

SMTP → external relay (Gmail/Mailjet now, Office 365 later). No Let's Encrypt.  
Images are **version-pinned** (not `:latest`) — see comments in `docker-compose.yml`.

> AD CS = HTTPS trust for clients. Real invite delivery = SMTP ([docs/smtp.md](docs/smtp.md)).

---

## Docs

| Doc | Topic |
|-----|--------|
| [docs/quick-start.md](docs/quick-start.md) | First boot, DNS, admin login |
| [docs/smtp.md](docs/smtp.md) | Gmail, Mailjet, Mailpit, Office 365 |
| [docs/email-oauth2-proxy.md](docs/email-oauth2-proxy.md) | O365 when basic SMTP AUTH is blocked |
| [docs/tls-certs.md](docs/tls-certs.md) | Caddy root GPO vs AD CS certs |
| [docs/organizations.md](docs/organizations.md) | Orgs, groups, collections, permission matrix |
| [docs/directory-connector.md](docs/directory-connector.md) | AD / LDAP sync with Bitwarden Directory Connector |
| [docs/backup.md](docs/backup.md) | NAS backups with offen/docker-volume-backup |
| [docs/lift-and-shift.md](docs/lift-and-shift.md) | On-site checklist + directory layout |
| [docs/operations.md](docs/operations.md) | Compose commands + hardening |

---

## One-liner start

```bash
cp .env.example .env
# set ADMIN_TOKEN (vaultwarden hash) + SMTP_* — see docs/quick-start.md
docker compose up -d
```
