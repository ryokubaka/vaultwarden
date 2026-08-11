# SMTP (invites)

No MTA in Compose by default. Vaultwarden talks to an external SMTP provider — same knobs for Gmail now and Office 365 later.

Invite links always use `DOMAIN` in `.env` (e.g. `https://vw.org-testing.meow`).

---

## Gmail app password (test now — real inbox)

1. Google account → enable 2FA → [App passwords](https://myaccount.google.com/apppasswords) → create one for “Mail”.
2. In `.env`:

   ```env
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_SECURITY=starttls
   SMTP_USERNAME=you@gmail.com
   SMTP_PASSWORD=xxxx xxxx xxxx xxxx
   SMTP_FROM=you@gmail.com
   SMTP_FROM_NAME=Vaultwarden
   ```

3. `docker compose up -d vaultwarden`
4. Admin → SMTP test → check Gmail (and spam).

Spaces in the app password are OK.

---

## Mailjet / Brevo / similar

1. Sign up, verify a sender address (or domain).
2. Put API SMTP host/user/password in `.env` (see `.env.example` block B).
3. `SMTP_FROM` must be a verified sender.
4. Recreate vaultwarden; run SMTP test.

---

## Optional: Mailpit (no real inbox)

```bash
# .env → SMTP_HOST=mailpit, SMTP_PORT=1025, SMTP_SECURITY=off (no user/pass)
docker compose --profile mailpit up -d
```

Invites appear at `https://mail.org-testing.meow` only.

---

## Office 365 (later — production)

Goal: invites look like normal corporate email.

1. Keep `DOMAIN=https://vw.org-testing.meow` so invite links stay correct.
2. Set `SMTP_FROM` to an address the tenant accepts.
3. Update `.env`; `docker compose up -d vaultwarden`.
4. If Mailpit was used: `docker compose --profile mailpit stop mailpit`.

Sections below are **best → worst for security**. Difficulty noted on each heading.

**Caveat:** IP connector with a **shared** plant WAN IP can be worse than the others — use a VW-only static egress IP.

---

### Option 1 — SMTP relay connector (IP allowlist) — recommended

**Security:** Best — no mailbox password on the host; no basic AUTH. Trust = static egress IP.  
**Difficulty:** Medium (Exchange connector, SPF, outbound TCP 25, static IP).

Microsoft’s “SMTP relay” path: Exchange Online trusts your **static public egress IP(s)**. No username/password in Vaultwarden. Official guide: [Set up a multifunction device or application to send email](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365) (their SMTP relay option).

#### What you need from the plant / network

| Item | Notes |
|------|--------|
| **Static public IPv4** | Egress IP of the Vaultwarden host (or NAT). Dynamic WAN IPs break when they change. Lock connector to **this host only**, not a whole site range. |
| **Outbound TCP 25** | Host → internet (many ISPs block 25 — confirm). |
| **Accepted domain** | Sender address must be in a verified M365 domain (e.g. `vaultwarden@contoso.com`). |

#### A) Find your MX endpoint (SMTP host name)

1. Sign in to [Microsoft 365 admin center](https://admin.microsoft.com).
2. **Settings** → **Domains** → select the sending domain (must be **Healthy**).
3. **DNS records** → find the **MX** record.
4. Copy **Points to address**, e.g. `contoso-com.mail.protection.outlook.com`.

That hostname is Vaultwarden’s `SMTP_HOST` — **not** `smtp.office365.com` (that one is for SMTP AUTH).

#### B) Create the inbound connector (Exchange admin)

Needs Exchange Admin (or equivalent).

1. Open [Exchange admin center](https://admin.exchange.microsoft.com) → **Mail flow** → **Connectors**.
2. **Add a connector**.
3. **Connection from:** **Your organization’s email server** → **To:** **Office 365** → Next.
4. Name it (e.g. `SMTP Relay – Plant Vaultwarden`) → leave **Turn it on** checked → Next.
5. Authenticating sent email:
   - Choose **By verifying that the IP address of the sending server matches one of these IP addresses that belong to your organization**.
   - **+** add the plant static public IP(s) → Next.
6. Review → **Create connector**.

(If a connector “from your organization’s email server” already exists, edit it and add the new IP(s) rather than creating a duplicate.)

#### C) Update SPF (DNS)

```text
v=spf1 ip4:203.0.113.40 include:spf.protection.outlook.com -all
```

(Use the real egress IP; merge with existing SPF — don’t create a second SPF record.)

#### D) Vaultwarden `.env`

```env
SMTP_HOST=contoso-com.mail.protection.outlook.com
SMTP_PORT=25
SMTP_SECURITY=starttls
SMTP_FROM=vaultwarden@contoso.com
SMTP_FROM_NAME=Vaultwarden
# Do NOT set SMTP_USERNAME / SMTP_PASSWORD for IP relay
```

```bash
docker compose up -d vaultwarden
# Admin → SMTP → Send test email
```

| Setting | Value |
|---------|--------|
| Host | MX endpoint from step A |
| Port | **25** |
| TLS | STARTTLS (`SMTP_SECURITY=starttls`) |
| Auth | None |

#### E) Test / troubleshoot

```bash
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/contoso-com.mail.protection.outlook.com/25'; echo $?
# 0 = TCP reachability OK
```

| Symptom | Likely cause |
|---------|----------------|
| Timeout on :25 | ISP/firewall blocking outbound 25 |
| 5.7.64 / not authenticated | Connector missing or wrong public IP |
| Accepted internally, external junk/reject | SPF not updated |
| Works then stops | WAN IP changed (wasn’t static) |

Message trace: Exchange admin → **Mail flow** → **Message trace**.

---

### Option 2 — OAuth2 proxy

**Security:** Strong — modern OAuth; refresh token still on disk.  
**Difficulty:** Hard (Entra app, proxy container, consent, token hygiene).

Use when IT will not do an IP connector and blocks basic SMTP AUTH.

Vaultwarden does **not** speak Microsoft OAuth2 SMTP natively. Error often: `No compatible authentication mechanism was found`.

→ Full guide: **[email-oauth2-proxy.md](email-oauth2-proxy.md)**

```bash
cp emailproxy/emailproxy.config.example emailproxy/emailproxy.config
# Edit: mailbox, tenant ID, Entra client_id / client_secret
```

```env
SMTP_HOST=emailproxy
SMTP_PORT=1587
SMTP_SECURITY=off
SMTP_USERNAME=vaultwarden@contoso.com
SMTP_PASSWORD=proxy-local-secret
SMTP_FROM=vaultwarden@contoso.com
```

```bash
docker compose --profile oauth-smtp up -d
# Authorize via device code in emailproxy logs, then Admin → SMTP test
```

---

### Option 3 — SMTP AUTH (mailbox + username/password)

**Security:** Weakest — password in `.env`; basic AUTH; MFA usually bypassed; Microsoft deprecating.  
**Difficulty:** Easy (enable AUTH on one mailbox, put creds in `.env`).

Short-term bridge only. Dedicated service mailbox — not a human’s daily account.

```text
Vaultwarden  --STARTTLS + LOGIN-->  smtp.office365.com:587  -->  recipient inbox
                 (user + password)
```

Official docs:

- [Enable or disable SMTP AUTH](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/authenticated-client-smtp-submission)
- [Device/app send email (Microsoft)](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365)

Vaultwarden only speaks **basic** SMTP AUTH, **not** OAuth2. If basic auth is blocked → [Option 1](#option-1--smtp-relay-connector-ip-allowlist--recommended) or [Option 2](#option-2--oauth2-proxy).

#### What you need

| Item | Notes |
|------|--------|
| **Licensed user mailbox** | e.g. `vaultwarden@contoso.com` with Exchange Online |
| **Password (or app password)** | MFA without app passwords often breaks this → Option 1 or 2 |
| **Authenticated SMTP enabled** | On that mailbox |
| **Outbound TCP 587** | To `smtp.office365.com` |
| **Security defaults / auth policies** | Can block SMTP AUTH even when mailbox toggle is on |

#### A) Create / pick the mailbox

1. [Microsoft 365 admin center](https://admin.microsoft.com) → **Users** → **Active users** → **Add a user**.
2. Assign Exchange Online license.
3. Sign in once (Outlook on the web) to finish provisioning.
4. Dedicated account only for Vaultwarden.

#### B) Enable Authenticated SMTP on that mailbox

**UI:** user → **Mail** → **Manage email apps** → check **Authenticated SMTP** → Save.

**PowerShell:**

```powershell
Connect-ExchangeOnline
Set-CASMailbox -Identity vaultwarden@contoso.com -SmtpClientAuthenticationDisabled $false
Get-CASMailbox -Identity vaultwarden@contoso.com | Format-List SmtpClientAuthenticationDisabled
# False = SMTP AUTH enabled
```

#### C) Org-wide SMTP AUTH

Many tenants disable SMTP AUTH globally, then enable per mailbox (step B). That is fine.

```powershell
Get-TransportConfig | Format-List SmtpClientAuthenticationDisabled
# True  = org default off
# False = org default on
```

Also check Entra Security defaults and authentication policies that disable basic auth for SMTP.

#### D) Password / MFA

| Situation | `SMTP_PASSWORD` |
|-----------|-----------------|
| No MFA | Account password |
| MFA + app passwords allowed | App password |
| MFA, no app passwords / basic blocked | Use Option 1 or 2 instead |

#### E) Vaultwarden `.env`

```env
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=vaultwarden@contoso.com
SMTP_PASSWORD='your-password-or-app-password'
SMTP_FROM=vaultwarden@contoso.com
SMTP_FROM_NAME=Vaultwarden
```

```bash
docker compose up -d vaultwarden
# Admin → SMTP → Send test email
```

#### F) Troubleshoot

| Symptom | Likely cause |
|---------|----------------|
| `No compatible authentication mechanism was found` | Basic AUTH blocked → Option 1 or 2 |
| `Authentication unsuccessful` / 535 | Wrong password; MFA; Authenticated SMTP off |
| Timeout on 587 | Firewall/egress block |

Microsoft is [retiring basic auth for SMTP](https://techcommunity.microsoft.com/t5/exchange-team-blog/exchange-online-to-retire-basic-auth-for-client-submission-smtp/ba-p/4114750) — prefer Option 1 or 2 long-term.

---

## Shared hard rules (any O365 option)

- Dedicated send identity (`vaultwarden@…`) — not a person’s mailbox.
- Least privilege; alert on unusual send volume.
- VW Admin + `.env` + data backups are crown jewels.
- Restrict who can reach the VW host.

**AD CS does not make email trusted.** HTTPS trust ≠ Outlook delivery.
