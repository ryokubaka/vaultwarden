# Organizations, groups, collections

**Org** = one company vault.  
**Groups** = roles (`IT-*` and `OT-*`).  
**Collections** = secret sets.

`ORG_GROUPS_ENABLED=true` in this pack. Isolation is groups × collections. Do not create a second org.

| Code  | Meaning                                 |
| ----- | --------------------------------------- |
| **V** | View items                              |
| **E** | Edit items (implies view)               |
| **M** | Manage collection access (implies edit) |

Org-level: one **Owner** (breakglass human) and almost nobody as **Admin**. Everyone else is **User**. Access is groups, not org Admin.

An org Admin can see every collection. Do not make an IT-only or OT-only person an org Admin. That would show them the other side's breakglass.

IT model: **admins vs everyone else** for privileged infra (no separate “sysadmin” group). Specialty groups (`Helpdesk`, `Network`) only where the job is clearly different.

Default org name from utility-support is `Plant`. Override with `VW_ORG_NAME`.

---

## Build order

1. Create the org → you are Owner.
2. Create collections (empty first).
3. Create groups (manually **or** sync from AD — [directory-connector.md](directory-connector.md)).
4. Assign groups → collections (tables below). Collection ACLs are **not** synced from AD.
5. Invite / sync users → put them in groups only.

---

## Groups


| Group          | Who                                                    |
| -------------- | ------------------------------------------------------ |
| `IT-Users`     | General IT staff                                       |
| `IT-Helpdesk`  | Helpdesk / endpoint support                            |
| `IT-Network`   | Firewall, switch, VPN, DNS                             |
| `IT-Admins`    | Privileged IT (servers, apps, breakglass — few people) |
| `IT-Vendors`   | Temp MSP / contractors                                 |
| `OT-Operators` | Control room / board operators                         |
| `OT-Engineers` | Controls / SCADA / instrumentation engineering         |
| `OT-Admins`    | OT privileged (very few)                               |
| `OT-Vendors`   | OEM / integrator temp                                  |


---

## IT collections × groups


| Collection        | IT-Users | IT-Helpdesk | IT-Network | IT-Admins | IT-Vendors |
| ----------------- | -------- | ----------- | ---------- | --------- | ---------- |
| `IT-Shared-Staff` | V        | E           | E          | M         | —          |
| `IT-Endpoints`    | —        | E           | —          | M         | V*         |
| `IT-Apps`         | V†       | —           | —          | M         | V*         |
| `IT-Servers`      | —        | —           | V          | M         | V*         |
| `IT-Network`      | —        | —           | E          | M         | V*         |
| `IT-Cloud-SaaS`   | V†       | —           | —          | M         | —          |
| `IT-Vendor`       | —        | —           | V          | M         | E*         |
| `IT-Breakglass`   | —        | —           | —          | M         | —          |


* Vendor = time-boxed; remove after engagement.  
† Optional non-privileged shared app logins only.

IT groups have no grants on `OT-*` collections. OT groups have no grants on `IT-*` collections.

---

## OT collections × groups


| Collection      | What’s in it                           | OT-Operators | OT-Engineers | OT-Admins | OT-Vendors |
| --------------- | -------------------------------------- | ------------ | ------------ | --------- | ---------- |
| `OT-HMI`        | Operator HMI / thin-client logins      | V            | E            | M         | —          |
| `OT-PLCs`       | PLC / RTU / PAC passwords              | —            | E            | M         | V*         |
| `OT-Servers`    | SCADA servers, historians, process DBs | —            | E            | M         | V*         |
| `OT-Network`    | OT switches, firewalls, radios         | —            | E            | M         | V*         |
| `OT-Vendor`     | OEM / integrator remote access         | —            | V            | M         | E*         |
| `OT-Emergency`  | On-call / incident runbook secrets     | V§           | E            | M         | —          |
| `OT-Breakglass` | Highest-privilege OT recovery          | —            | —            | M         | —          |


* Vendor = time-boxed.  
§ On-call / incident only; keep small.

**Never** put PLC/engineering passwords in `OT-HMI`.  
**Never** put OT secrets in `IT-*` collections.

---

## Org roles


| People                   | Org role | Groups                                          |
| ------------------------ | -------- | ----------------------------------------------- |
| 1–2 breakglass humans    | Owner    | `IT-Admins` and `OT-Admins`                     |
| Day-to-day privileged IT | User     | `IT-Admins` (+ specialty if needed)             |
| Controls leads           | User     | `OT-Admins` and/or `OT-Engineers`               |
| Everyone else            | User     | Role group(s) only                              |


Dual-hat people stay in one org. Put them in both an IT group and an OT group.

---

## Account recovery

Turn this on after the org exists. Admin Console, Policies, Account recovery administration. Check **Turn on** and **Automatically enroll new members**.

The [utility-support](https://github.com/ryokubaka/utility-support) quickstart turns account recovery on. Standalone `docker compose` does not. Do it in the UI, or re-run that bootstrap.

Leave Single organization off if you also have a staff org (for example `GWA-Employees`). That policy removes members who belong to another org. IT vs OT does not need it.

Auto-enroll covers people invited after the policy is on. Anyone who already has a master password must self-enroll once before an admin can recover that account.

---

## Cross-cutting rules

1. Dual-hat people → extra groups in the same org, not a second org.
2. Default deny — new collection has no groups until attached.
3. Breakglass — `*-Admins` only; rotate after use.
4. Vendors — empty by default; calendar expiry; strip after.
5. Personal vaults — personal logins only; plant secrets → org collections.
6. Account recovery on. Single organization off unless this is the only org.

---

## Minimal start (tiny headcount)

Collections: `IT-Shared-Staff` · `IT-Servers` · `IT-Breakglass` · `OT-HMI` · `OT-PLCs` · `OT-Breakglass`

Groups: `IT-Users` → Shared V; `IT-Admins` → all IT M; `OT-Operators` → HMI V; `OT-Engineers` → PLCs E; `OT-Admins` → all OT M
