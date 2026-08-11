# Lift-and-shift checklist

## At home / build machine

- [ ] `docker compose pull`
- [ ] `.env` with Argon2 `ADMIN_TOKEN` + working external SMTP ([smtp.md](smtp.md))
- [ ] Stack starts; admin SMTP test + real invite to your inbox
- [ ] Optional: export Caddy root (`./scripts/export-caddy-root.sh`) for [tls-certs.md](tls-certs.md) Path A
- [ ] Copy entire `portable/` directory (`data/` only if you want pre-seeded state; usually empty on site)

## On site

- [ ] Host with Docker Engine + Compose plugin
- [ ] Static IP or DHCP reservation
- [ ] Firewall: clients → host `:443` (and `:80` if using Caddy HTTP redirect)
- [ ] Host outbound 587/465 to SMTP provider (or O365)
- [ ] AD DNS (or hosts) for `vw.org-testing.meow`
- [ ] `docker compose up -d`
- [ ] Path A (GPO Caddy root) **or** Path B (AD CS) — [tls-certs.md](tls-certs.md)
- [ ] Create orgs / collections / groups — [organizations.md](organizations.md); disable public signups
- [ ] Optional: [Directory Connector](directory-connector.md)
- [ ] When IT ready: switch SMTP to Office 365 — [smtp.md](smtp.md)

## Layout

```
portable/
  README.md                 # index
  docs/                     # this documentation
  docker-compose.yml
  Caddyfile                 # tls internal (default)
  Caddyfile.adcs.example    # AD CS PEMs
  .env.example
  .gitignore
  certs/                    # AD CS PEMs (gitignored except .gitkeep)
  emailproxy/               # OAuth SMTP proxy config + token cache
  scripts/export-caddy-root.sh
  data/                     # Vaultwarden data (contents gitignored)
  caddy-data/
  caddy-config/
```
