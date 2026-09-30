# SMTP (invites)

No MTA in Compose by default. Vaultwarden talks to an external SMTP provider. Same knobs for Gmail, Hostway SiteControl, Mailjet, Office 365, or Barracuda.

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

## Hostway SiteControl

Mailbox AUTH through Hostway SiteProtect SMTP. Official client settings: [How to configure my email client](https://support.hostway.com/hc/en-us/articles/115000368264-How-To-Configure-My-Email-Client-General-Instructions).

Username is the full mailbox address. Password is that mailbox password. Use a dedicated mailbox, not a person's daily inbox.

1. In SiteControl, confirm the mailbox exists and you can log in to webmail.
2. In `.env`:

   ```env
   SMTP_HOST=smtp.siteprotect.com
   SMTP_PORT=587
   SMTP_SECURITY=starttls
   SMTP_USERNAME=vaultwarden@yourdomain.com
   SMTP_PASSWORD=
   SMTP_FROM=vaultwarden@yourdomain.com
   SMTP_FROM_NAME=Vaultwarden
   ```

3. `docker compose up -d vaultwarden`
4. Admin → SMTP test → check inbox and spam.

If the plant firewall or ISP blocks 587, Hostway's alternate is port 465 with implicit TLS:

```env
SMTP_PORT=465
SMTP_SECURITY=force_tls
```

Older Hostway pages used `smtp.yourdomain.com`. Current SiteControl / Open-Xchange mail uses `smtp.siteprotect.com`.

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

## Barracuda Email Solutions (production)

Goal: same as O365. Invites look like normal corporate email. Keep `DOMAIN=https://vw.org-testing.meow` so invite links stay correct.

Barracuda is a gateway, not a mailbox. Pick the product they actually run before editing `.env`.

| What IT has | Use |
|-------------|-----|
| **Email Security Gateway** (on-prem appliance, LAN IP) | [Option 1](#option-1--email-security-gateway-on-prem--ip-allowlist--recommended) |
| **Email Gateway Defense** (cloud / ESS, hostname like `dXXXX.ess.barracudanetworks.com`) | [Option 2](#option-2--email-gateway-defense-cloud--ess) |
| SASL / SMTP AUTH already enabled on the gateway | [Option 3](#option-3--smtp-auth-sasl--mailbox-password) |
| Barracuda only filters **inbound**; mailboxes and outbound are still O365 | Stay on [Office 365](#office-365-later--production) |

Quick tell: `dig MX contoso.com`. MX ending in `.ess.barracudanetworks.com` is cloud. MX pointing at a hostname they own is usually the appliance (or something in front of it).

Official refs:

- Appliance: [How to Route Outbound Mail from the Barracuda Email Security Gateway](https://documentation.campus.barracuda.com/wiki/spaces/BSFv51/pages/6685003/How+to+Route+Outbound+Mail+from+the+Barracuda+Email+Security+Gateway)
- Cloud: [Configure Email Gateway Defense for on-prem mail servers](https://documentation.campus.barracuda.com/wiki/spaces/EGD/pages/2850896/Step+2+-+Configure+Email+Gateway+Defense+for+Exchange+2016+and+Other+On-Premise+Mail+Servers)

If Mailpit was used: `docker compose --profile mailpit stop mailpit`.

**Caveat:** lock the allowlist to the **Vaultwarden host only**. A whole plant WAN/LAN range turns every machine on that net into an open relay through Barracuda.

---

### Option 1 — Email Security Gateway (on-prem) — IP allowlist — recommended

**Security:** Best for the appliance — no mailbox password on the host. Trust = VW host IP.  
**Difficulty:** Easy if IT already relays outbound through the box; Medium if outbound scanning is not set up yet.

#### What you need from IT / network

| Item | Notes |
|------|--------|
| **ESG hostname or LAN IP** | The appliance Vaultwarden can reach. Not the public MX unless they published it. |
| **VW host IP (or NAT)** | The address the appliance sees. Add **this** IP, not a /16. |
| **Outbound TCP 25** | Host → ESG. Confirm the appliance accepts STARTTLS (`ADVANCED` → **Email Protocol**). |
| **Accepted domain** | `SMTP_FROM` must be a domain the gateway is allowed to send as. |
| **Rate-control exemption** | ESG rate-limits outbound. Exempt the VW IP or invites get throttled. |

#### A) Allow the Vaultwarden host to relay

Needs Barracuda admin.

1. Open the Email Security Gateway web UI.
2. **BASIC** → **Outbound**.
3. **Relay Using Trusted IP/Range** → add the Vaultwarden host IP (netmask `255.255.255.255` for a single host).
4. Barracuda wants IPs here, not hostnames. A hostname in **Relay Using Trusted Host/Domain** also needs SMTP AUTH or LDAP.
5. **BLOCK/ACCEPT** → **Rate Control** → **Rate Control Exemption IP/Range** → same IP.
6. Confirm outbound scanning already works for their mail server. If it does not, IT must finish [outbound routing](https://documentation.campus.barracuda.com/wiki/spaces/BSFv51/pages/6685003/How+to+Route+Outbound+Mail+from+the+Barracuda+Email+Security+Gateway) before Vaultwarden will go anywhere.

Optional: **Senders With Relay Permission** can pin the From address to `vaultwarden@contoso.com`. Barracuda themselves say From-only lists are spoofable. Keep the IP allowlist as the real control.

#### B) Vaultwarden `.env`

```env
SMTP_HOST=esg.contoso.local
SMTP_PORT=25
SMTP_SECURITY=starttls
SMTP_FROM=vaultwarden@contoso.com
SMTP_FROM_NAME=Vaultwarden
# Do NOT set SMTP_USERNAME / SMTP_PASSWORD for IP relay
```

If the appliance does not offer STARTTLS on the LAN hop, set `SMTP_SECURITY=off` and keep this on the internal network only.

```bash
docker compose up -d vaultwarden
# Admin → SMTP → Send test email
```

| Setting | Value |
|---------|--------|
| Host | ESG hostname or LAN IP |
| Port | **25** (unless IT published submission elsewhere) |
| TLS | STARTTLS if the box supports it |
| Auth | None |

#### C) Test / troubleshoot

```bash
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/esg.contoso.local/25'; echo $?
# 0 = TCP reachability OK
```

Check ESG **BASIC** → **Message Log** (direction: Outbound). Invite HTML with a `https://vw…` link can look like phishing. If the test never arrives, look at outbound quarantine and **BLOCK/ACCEPT** content filters.

| Symptom | Likely cause |
|---------|----------------|
| Timeout on :25 | Host cannot reach ESG; firewall |
| Relaying denied / 550 | VW IP not in Trusted IP/Range, or appliance sees a different NAT IP |
| Accepted then silent | Rate control; outbound quarantine; content filter on the invite URL |
| Works on LAN, dies off-site | ESG is not a public SMTP host — do not point `SMTP_HOST` at the internet MX |

---

### Option 2 — Email Gateway Defense (cloud / ESS)

**Security:** Strong if the sender IP list is a single static egress. No password in `.env`.  
**Difficulty:** Medium (Barracuda Cloud Control, static public IP, SPF, outbound TCP 25).

Same idea as the O365 IP connector. The smarthost is Barracuda’s cloud hostname. Auth is none. They trust your public IP.

Official path: [EGD for on-prem mail servers](https://documentation.campus.barracuda.com/wiki/spaces/EGD/pages/2850896/Step+2+-+Configure+Email+Gateway+Defense+for+Exchange+2016+and+Other+On-Premise+Mail+Servers) (steps 4–5). Skip the Exchange send-connector and point Vaultwarden at the hostname instead.

#### What you need

| Item | Notes |
|------|--------|
| **Outbound Hostname** | Cloud Control → Email Gateway Defense → **Domains** → **Domain Manager**. Looks like `dXXXXXXX.ess.barracudanetworks.com` (region suffix may differ). |
| **Static public IPv4** | Egress IP of the Vaultwarden host. Dynamic WAN IPs break when they change. |
| **Outbound TCP 25** | Host → internet. Many ISPs block 25. |
| **Verified domain** | Sending domain must already be in EGD. |
| **SPF** | Include Barracuda’s SPF for the region. |

#### A) Allow the plant egress IP

1. Sign in to [Barracuda Cloud Control](https://login.barracudanetworks.com) → **Email Gateway Defense**.
2. **Outbound Settings** → **Sender IP Address Ranges**.
3. Add the Vaultwarden **public** egress IP and the logging domain (the From domain).
4. Comment it (`Vaultwarden plant host`) so the next admin does not treat it as leftover Exchange.

#### B) SPF

Merge into the existing SPF record. Do not create a second one. Pick the include for their Barracuda region:

```text
# US
v=spf1 ip4:203.0.113.40 include:spf.ess.barracudanetworks.com -all
```

Other regions: `spf.ess.au.barracudanetworks.com`, `.ca.`, `.de.`, `.in.`, `.uk.`.

If they already include Barracuda for Exchange outbound, adding the VW `ip4:` is still worth it while the message is in flight. Keep the include so mail that left via EGD passes SPF at the recipient.

#### C) Vaultwarden `.env`

```env
SMTP_HOST=dXXXXXXX.ess.barracudanetworks.com
SMTP_PORT=25
SMTP_SECURITY=starttls
SMTP_FROM=vaultwarden@contoso.com
SMTP_FROM_NAME=Vaultwarden
# Do NOT set SMTP_USERNAME / SMTP_PASSWORD
```

`SMTP_HOST` is the **Outbound Hostname** from Domain Manager. Do not use the inbound MX unless IT confirms they are the same.

```bash
docker compose up -d vaultwarden
# Admin → SMTP → Send test email
```

#### D) Test / troubleshoot

EGD **Dashboard** / message log, direction outbound.

| Symptom | Likely cause |
|---------|----------------|
| Timeout on :25 | ISP/firewall blocking outbound 25 |
| Rejected / not authorized | Sender IP missing or wrong (NAT, extra hop) |
| Domain not allowed | From domain not in Domain Manager |
| Accepted internally, external junk/reject | SPF include missing |
| Works then stops | WAN IP changed |

---

### Option 3 — SMTP AUTH (SASL / mailbox password)

**Security:** Weaker — password in `.env`.  
**Difficulty:** Easy if IT already enabled SASL on the gateway.

Use when they will not add an IP to the trusted-relay list.

ESG: **BASIC** → **Outbound** → **Enable SASL/SMTP Authentication**. Either proxy AUTH to the destination mail server, or LDAP. Enable SMTP over TLS on **ADVANCED** → **Email Protocol** so the password is not cleartext.

Dedicated service account. Not a human mailbox.

```env
SMTP_HOST=esg.contoso.local
SMTP_PORT=25
SMTP_SECURITY=starttls
SMTP_USERNAME=vaultwarden@contoso.com
SMTP_PASSWORD='your-password'
SMTP_FROM=vaultwarden@contoso.com
SMTP_FROM_NAME=Vaultwarden
```

Use port **587** only if IT published submission there. Cloud EGD outbound is IP-based; AUTH is an appliance feature.

| Symptom | Likely cause |
|---------|----------------|
| `No compatible authentication mechanism` | SASL not enabled, or AUTH not offered on that port |
| `Authentication unsuccessful` / 535 | Wrong password; LDAP/mail server AUTH proxy misconfigured |
| Password works in Outlook, not here | VW speaks basic SMTP AUTH only |

---

## Shared hard rules (O365 or Barracuda)

- Dedicated send identity (`vaultwarden@…`) — not a person’s mailbox.
- Least privilege; alert on unusual send volume.
- VW Admin + `.env` + data backups are crown jewels.
- Restrict who can reach the VW host.

**AD CS does not make email trusted.** HTTPS trust ≠ Outlook delivery.
