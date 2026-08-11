# Operations and hardening

## Day-to-day commands

```bash
# Start / stop (external SMTP — default)
docker compose up -d
docker compose down

# Optional Mailpit catch-all
docker compose --profile mailpit up -d

# Optional O365 OAuth2 SMTP proxy
docker compose --profile oauth-smtp up -d

# Logs
docker compose logs -f vaultwarden caddy
# docker compose logs -f emailproxy

# Update images
docker compose pull && docker compose up -d
```

| UI | URL |
|----|-----|
| Web vault | `https://vw.org-testing.meow` |
| Server admin | `https://vw.org-testing.meow/admin` |
| Mailpit (profile) | `https://mail.org-testing.meow` |

Server admin password = secret used with `vaultwarden hash` (not the PHC string in `.env`).

Org Admin Console (collections / members / groups) = web vault → organization → **Admin Console**.

---

## Hardening

- Set `SIGNUPS_ALLOWED=false` after the first admin exists.
- Keep `ORG_GROUPS_ENABLED=true` unless you hit a known client bug; prefer groups over many orgs.
- Store `ADMIN_TOKEN` as an Argon2 PHC (`vaultwarden hash`); keep the plaintext secret in a password manager, not only in `.env`.
- If Admin → Save created `data/config.json`, that file overrides env — update the token there or remove `"admin_token"` and recreate the container.
- Restrict who can reach `:443` (mgmt VLAN / VPN).
- Backup `./data` regularly (SQLite + attachments + config).
- `SHOW_PASSWORD_HINT=false` is the default in `.env.example`.
