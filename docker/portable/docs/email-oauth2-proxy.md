# Office 365 via email-oauth2-proxy

Vaultwarden has **no native OAuth2 SMTP**. Many O365 tenants block basic SMTP AUTH → error like `No compatible authentication mechanism was found`.

[email-oauth2-proxy](https://github.com/simonrob/email-oauth2-proxy) sits between Vaultwarden and Microsoft: VW uses normal USER/PASS to the proxy; the proxy talks to O365 with OAuth2.

Upstream note: [Vaultwarden SMTP wiki — OAuth2](https://github.com/dani-garcia/vaultwarden/wiki/SMTP-Configuration).

```text
Vaultwarden  --SMTP (plain AUTH)-->  email-oauth2-proxy  --OAuth2 SMTP-->  smtp.office365.com
```

---

## When to use this

Try in order (security best → worst — see [smtp.md](smtp.md)):

1. **IP connector** (SMTP relay) — [smtp.md](smtp.md) Option 1 — preferred  
2. **This proxy** — when IT won’t do a connector and blocks basic SMTP AUTH  
3. **SMTP AUTH** (password in `.env`) — [smtp.md](smtp.md) Option 3 — last resort

---

## Prerequisites

- [ ] Licensed mailbox for sending (e.g. `vaultwarden@contoso.com`) — shared mailbox OK if a user can send as it  
- [ ] Entra ID (Azure AD) admin who can register an app  
- [ ] Host outbound HTTPS to `login.microsoftonline.com` + SMTP to `smtp.office365.com:587`  
- [ ] This portable pack with Docker Compose  

---

## 1) Register an Entra ID application

In [Entra admin center](https://entra.microsoft.com/) → **App registrations** → **New registration**:

| Field | Value |
|-------|--------|
| Name | e.g. `Vaultwarden SMTP OAuth Proxy` |
| Supported account types | **Single tenant** (this org only) |
| Redirect URI | Platform **Public client/native**: `https://login.microsoftonline.com/common/oauth2/nativeclient` (device flow) |

Then:

1. **Overview** — copy **Application (client) ID** and **Directory (tenant) ID**.
2. **Certificates & secrets** → **New client secret** → copy the **Value** once (or use a public client without secret if your registration allows — then omit `client_secret` in config).
3. **API permissions** → **Add a permission** → **Microsoft Graph** is *not* enough for SMTP. Add **Office 365 Exchange Online** (or **Outlook**) delegated permissions:
   - `SMTP.Send`
   - `offline_access` (often under Microsoft Graph / OpenID — include it in the OAuth scope string either way)
4. **Grant admin consent** for the tenant.
5. **Authentication** → enable **Allow public client flows** = **Yes** (needed for device code flow).

Exact permission blade names move around; the OAuth **scope** the proxy requests must include:

```text
https://outlook.office.com/SMTP.Send offline_access
```

If consent fails, have a Global Admin grant consent for the app.

---

## 2) Config file in this pack

```bash
cd docker/portable
cp emailproxy/emailproxy.config.example emailproxy/emailproxy.config
```

Edit `emailproxy/emailproxy.config`:

1. Rename `[vaultwarden@contoso.com]` to the real mailbox address.
2. Set `YOUR_TENANT_ID`, `client_id`, `client_secret`.
3. Keep `local_address = 0.0.0.0` (required in Docker).
4. Keep `oauth2_flow = device` for headless servers (no browser on the VW host).

Do **not** commit `emailproxy.config` (gitignored) — it will hold refresh tokens after auth.

---

## 3) Compose profile + Vaultwarden SMTP

This pack includes an optional service (profile `oauth-smtp`).

**`.env`** (point VW at the proxy, not at Microsoft):

```env
SMTP_HOST=emailproxy
SMTP_PORT=1587
SMTP_SECURITY=off
SMTP_USERNAME=vaultwarden@contoso.com
SMTP_PASSWORD=proxy-local-secret
SMTP_FROM=vaultwarden@contoso.com
SMTP_FROM_NAME=Vaultwarden
```

Notes:

- Local hop VW → proxy is **unencrypted** by design (compose network only). Proxy → Microsoft uses STARTTLS.
- `SMTP_PASSWORD` is **not** the O365 password. It only encrypts the proxy’s cached tokens. Pick a long random string; use the **same** value whenever anything authenticates through the proxy for that account.
- `SMTP_USERNAME` / section name in `emailproxy.config` must match the mailbox.

Start:

```bash
docker compose --profile oauth-smtp up -d
docker compose logs -f emailproxy
```

---

## 4) Complete device-code authorization (once)

1. Watch logs: `docker compose logs -f emailproxy`
2. Trigger SMTP from Vaultwarden: Admin → **SMTP** → **Send test email** (or send an invite).
3. Proxy prints a **device code** URL + code (Microsoft device login).
4. On any browser (admin laptop): open the URL, enter the code, sign in as a user who can **send as** that mailbox, accept consent.
5. Proxy caches refresh token under `emailproxy/` (or `CACHE_STORE` path). Later sends need no interactive login until consent is revoked / secret expires.

If the test fails before you finish auth, send the test again after authorizing.

---

## 5) Verify

- Admin → SMTP test → message arrives in a real inbox.
- `docker compose logs vaultwarden` — no `No compatible authentication mechanism`.
- `docker compose logs emailproxy` — successful SMTP after OAuth.

---

## Operations

```bash
# Start stack including proxy
docker compose --profile oauth-smtp up -d

# Logs
docker compose logs -f emailproxy vaultwarden

# After editing emailproxy.config
docker compose --profile oauth-smtp up -d emailproxy
```

| Item | Location |
|------|----------|
| Config + tokens | `./emailproxy/` (persist; back up securely) |
| Image | `blacktirion/email-oauth2-proxy-docker` ([upstream Docker wrap](https://github.com/blacktirion/email-oauth2-proxy-docker)) |

Revoke access: Entra → enterprise app → revoke user consent, or rotate client secret and re-auth.

---

## Alternatives inside the proxy

Documented in [upstream config](https://github.com/simonrob/email-oauth2-proxy/blob/main/emailproxy.config):

| Flow | When |
|------|------|
| **device** (this pack’s default) | Headless Docker; admin authorizes from another PC |
| **local-server-auth** | Interactive browser redirect to a published proxy port |
| **client_credentials** | App-only mail send (needs Exchange application permissions + careful lockdown) |

Prefer **device** unless IT standardizes on CCG.

---

## Pitfalls

| Issue | Fix |
|-------|-----|
| VW can’t connect to `emailproxy` | Profile up? Same compose network? `local_address = 0.0.0.0`? |
| Auth mechanism error still | VW still pointing at `smtp.office365.com` — must use `SMTP_HOST=emailproxy`, `SMTP_SECURITY=off` |
| AADSTS errors / consent | Admin consent; SMTP.Send scope; public client flows on; correct tenant ID in URLs |
| Token expires every hour | Scope missing `offline_access` |
| Send as denied | Mailbox permissions / licensed user; shared mailbox send-as |
| Config lost after recreate | `./emailproxy` volume/bind must persist (`CACHE_STORE`) |

---

## Security notes

- Bind proxy **only** on the compose network (this pack does not publish `1587` to the host). Do not expose it to the LAN/internet.
- Treat `emailproxy.config` + token cache as secrets (refresh token ≈ mailbox send capability).
- Dedicated mailbox for Vaultwarden; least privilege.
