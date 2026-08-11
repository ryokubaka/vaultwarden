# Quick start

From `docker/portable`:

```bash
cp .env.example .env

# Hash a secret for the admin panel (interactive — type secret twice):
docker run --rm -it vaultwarden/server /vaultwarden hash
# Put the printed $argon2id$... value in .env with SINGLE quotes:
#   ADMIN_TOKEN='$argon2id$v=19$m=65540,t=3,p=4$...'
# /admin login password = the secret you typed (not the hash).

# Configure SMTP in .env — see [smtp.md](smtp.md)
docker compose up -d
docker compose logs -f
```

## DNS / hosts

Point the vault name at the host (AD DNS preferred on site; `/etc/hosts` OK for laptop demo):

```
<host-ip>  vw.org-testing.meow
```

Only needed for Mailpit UI: also add `mail.org-testing.meow`.

## First login

1. `https://vw.org-testing.meow` — create the first account.
2. Admin panel: `https://vw.org-testing.meow/admin` — password = secret used with `vaultwarden hash` (not the PHC string).
3. Admin → SMTP → **Send test email** to yourself; confirm inbox.
4. Set `SIGNUPS_ALLOWED=false` in `.env`, then `docker compose up -d vaultwarden`.
5. Org Groups are enabled (`ORG_GROUPS_ENABLED=true`). Web vault Admin Console → **Groups**.

Expect a cert warning until you trust the Caddy root or install AD CS certs — see [tls-certs.md](tls-certs.md).

## Next

- [smtp.md](smtp.md) — Gmail / Mailjet / Mailpit  
- [organizations.md](organizations.md) — orgs, groups, collections  
- [directory-connector.md](directory-connector.md) — AD sync  
- [lift-and-shift.md](lift-and-shift.md) — take it on site  
