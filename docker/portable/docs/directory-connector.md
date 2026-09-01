# Directory Connector (Active Directory / LDAP sync)

**Does:** pull users + groups from AD into a Vaultwarden **organization** (invite / remove / group membership).

**Does not:** AD password login. Users still set a Vaultwarden master password after accepting the invite.

Official docs: [About Directory Connector](https://bitwarden.com/help/directory-sync/) · [AD/LDAP settings](https://bitwarden.com/help/ldap-directory/) · [Desktop](https://bitwarden.com/help/directory-sync-desktop/) · [CLI](https://bitwarden.com/help/directory-sync-cli/).

**One Connector login** for the single org (default name `Plant`). One Organization API key, one sync.

Collection ACLs are set in Vaultwarden — see [organizations.md](organizations.md). Connector does not set them.

---

## Prerequisites

- [ ] The org exists (default `Plant`); you are **Owner**
- [ ] Account recovery on, auto-enroll on — [organizations.md](organizations.md). New invites then enroll without a click. People who already have a master password still self-enroll once.
- [ ] `ORG_GROUPS_ENABLED=true`
- [ ] `INVITATIONS_ALLOWED=true`
- [ ] SMTP working — [smtp.md](smtp.md)
- [ ] Connector host can reach Vaultwarden HTTPS and DC LDAP/LDAPS
- [ ] TLS trust on Connector host — [tls-certs.md](tls-certs.md)

---

## 1) Organization API key

In the **web vault** (not `/admin`):

1. Admin Console for the org.
2. **Settings** → **Organization info** / **API key**.
3. View / rotate — confirm with master password.
4. Save:

   | Field | Shape |
   |-------|--------|
   | `client_id` | `organization.<uuid>` |
   | `client_secret` | long random string |

Treat `client_secret` like a password.

---

## 2) Install

On a host that sees AD + Vaultwarden:

- Desktop: [releases](https://github.com/bitwarden/directory-connector/releases) / [installer docs](https://bitwarden.com/help/directory-sync-desktop/)
- CLI later: [CLI docs](https://bitwarden.com/help/directory-sync-cli/) (`bwdc`)

Do **not** run desktop + CLI on the same config DB at once.

---

## 3) Point at Vaultwarden

**Desktop:** Login → **Settings** → Server URL = `https://vw.org-testing.meow` → login with org API key.

**CLI:**

```bash
bwdc config server https://vw.org-testing.meow
bwdc login organization.<uuid> '<client_secret>'
```

Caddy `tls internal` cert errors (CLI):

```bash
export NODE_EXTRA_CA_CERTS=/path/to/exported-ca/caddy-local-root.crt
```

Windows: install root into Trusted Root store.

---

## 4) Connect to Active Directory

**Settings** → Type = **Active Directory / LDAP**:

| Setting | Typical AD value |
|---------|------------------|
| Server Hostname | `dc01.plant.local` |
| Server Port | `389` or `636` (LDAPS) |
| Root Path | `DC=plant,DC=local` |
| This server uses active directory | checked |
| Encrypted connection | prefer LDAPS / STARTTLS |
| Username | `PLANT\vw-sync` or bind DN |
| Password | service account password |

Use a **dedicated read-only sync account** (not Domain Admin). See [AD/LDAP article](https://bitwarden.com/help/ldap-directory/) for “remove disabled users” rights.

---

## 5) Sync options + filters

Enable **Sync users** and **Sync groups**.

Prefer AD group CNs that match Vaultwarden names (`Employees`, `IT-Admins`, `OT-Engineers`, …).

### Recommended: umbrella AD group (readable)

Create `Vaultwarden` in AD. Nest the IT and OT role groups under it (or add users to it).

**User filter** (who gets invited to the org):

```text
(&(objectCategory=Person)(sAMAccountName=*)(memberOf:1.2.840.113556.1.4.1941:=CN=Vaultwarden,OU=Groups,DC=plant,DC=local))
```

(`1.2.840.113556.1.4.1941` = nested group match. `memberOf` always needs the group’s **full DN**, not a bare CN.)

**Group filter** (which groups appear in VW):

```text
(&(objectCategory=group)(|(cn=Employees)(cn=IT-Users)(cn=IT-Helpdesk)(cn=IT-Network)(cn=IT-Admins)(cn=IT-Vendors)(cn=OT-Operators)(cn=OT-Engineers)(cn=OT-Admins)(cn=OT-Vendors)))
```

### Alternative: OU-scoped users

Put vault users under one OU (or a parent that holds both IT and OT). Set User Path accordingly; user filter can be simply “enabled persons”:

```text
(&(objectCategory=Person)(sAMAccountName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

Also set:

- **Remove disabled users during sync** — on for production
- **Interval** — e.g. `60` minutes if auto-sync
- More → **Clear Sync Cache** after big filter changes

Replace `DC=plant,DC=local` / OUs with the real domain DNs.

---

## 6) Test, then sync

1. **Dashboard** → **Test Now**
2. **Sync Now** (or **Start Sync**)
3. VW Admin Console → Members / Groups
4. Users accept invite → set master password → confirm if required
5. Attach groups → collections once ([organizations.md](organizations.md))

One org, one sync. Do not create a second Connector profile.

---

## 7) Schedule with CLI

```bash
bwdc config server https://vw.org-testing.meow
bwdc login   # BW_CLIENTID / BW_CLIENTSECRET
bwdc test
bwdc sync
```

Task Scheduler / cron hourly. One org, one task.

---

## Pitfalls

| Issue | Fix |
|-------|-----|
| TLS / issuer errors | Trust Caddy or AD CS root on Connector host |
| Login rejected | Wrong server URL; need **organization** API key; must be Owner to create key |
| Synced, no invite mail | Fix SMTP; `INVITATIONS_ALLOWED` |
| Groups empty in VW | `ORG_GROUPS_ENABLED=true`; enable Sync groups; widen group filter |
| Nested members missing | Use `1.2.840.113556.1.4.1941` in memberOf (umbrella group) |
| Disabled AD user still in org | Enable Remove disabled users |
| Expect AD password = vault password | Won’t happen — master password separate (OIDC SSO later if needed) |
