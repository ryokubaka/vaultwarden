# Organizations, groups, collections

**Orgs** = trust domains (IT vs OT).  
**Groups** = roles.  
**Collections** = secret sets.

`ORG_GROUPS_ENABLED=true` in this pack. Prefer groups over one-org-per-role.


| Code  | Meaning                                 |
| ----- | --------------------------------------- |
| **V** | View items                              |
| **E** | Edit items (implies view)               |
| **M** | Manage collection access (implies edit) |


Org-level: one **Owner** (breakglass human) + few **Admins** per org. Everyone else = **User**, access via groups.

IT model: **admins vs everyone else** for privileged infra (no separate “sysadmin” group). Specialty groups (`Helpdesk`, `Network`) only where the job is clearly different.

---

## Build order

1. Create org → you are Owner.
2. Create collections (empty first).
3. Create groups (manually **or** sync from AD — [directory-connector.md](directory-connector.md)).
4. Assign groups → collections (tables below). Collection ACLs are **not** synced from AD.
5. Invite / sync users → put them in groups only.

---

## Org 1: Org-IT

### Groups


| Group         | Who                                                    |
| ------------- | ------------------------------------------------------ |
| `IT-Users`    | General IT staff                                       |
| `IT-Helpdesk` | Helpdesk / endpoint support                            |
| `IT-Network`  | Firewall, switch, VPN, DNS                             |
| `IT-Admins`   | Privileged IT (servers, apps, breakglass — few people) |
| `IT-Vendors`  | Temp MSP / contractors                                 |


### Collections × groups


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


 Vendor = time-boxed; remove after engagement.  
† Optional non-privileged shared app logins only.

### Org roles (IT)


| People                   | Org role      | Groups                              |
| ------------------------ | ------------- | ----------------------------------- |
| 1–2 breakglass humans    | Owner         | `IT-Admins`                         |
| Day-to-day privileged IT | Admin or User | `IT-Admins` (+ specialty if needed) |
| Everyone else            | User          | Role group(s) only                  |


---

## Org 2: Org-OT

### Groups


| Group          | Who                                            |
| -------------- | ---------------------------------------------- |
| `OT-Operators` | Control room / board operators                 |
| `OT-Engineers` | Controls / SCADA / instrumentation engineering |
| `OT-Admins`    | OT privileged (very few)                       |
| `OT-Vendors`   | OEM / integrator temp                          |


### Collections × groups


| Collection      | What’s in it                           | OT-Operators | OT-Engineers | OT-Admins | OT-Vendors |
| --------------- | -------------------------------------- | ------------ | ------------ | --------- | ---------- |
| `OT-HMI`        | Operator HMI / thin-client logins      | V            | E            | M         | —          |
| `OT-PLCs`       | PLC / RTU / PAC passwords              | —            | E            | M         | V*         |
| `OT-Servers`    | SCADA servers, historians, process DBs | —            | E            | M         | V*         |
| `OT-Network`    | OT switches, firewalls, radios         | —            | E            | M         | V*         |
| `OT-Vendor`     | OEM / integrator remote access         | —            | V            | M         | E*         |
| `OT-Emergency`  | On-call / incident runbook secrets     | V§           | E            | M         | —          |
| `OT-Breakglass` | Highest-privilege OT recovery          | —            | —            | M         | —          |


 Vendor = time-boxed.  
§ On-call / incident only; keep small.

### Org roles (OT)


| People            | Org role      | Groups                            |
| ----------------- | ------------- | --------------------------------- |
| 1–2 OT breakglass | Owner         | `OT-Admins`                       |
| Controls leads    | Admin or User | `OT-Admins` and/or `OT-Engineers` |
| Operators         | User          | `OT-Operators`                    |


**Never** put PLC/engineering passwords in `OT-HMI`.  
**Never** dual-home OT secrets into Org-IT collections.

---

## Cross-cutting rules

1. Dual-hat people → members of **both orgs**, separate groups.
2. Default deny — new collection has no groups until attached.
3. Breakglass — `*-Admins` only; rotate after use.
4. Vendors — empty by default; calendar expiry; strip after.
5. Personal vaults — personal logins only; plant secrets → org collections.

---

## Minimal start (tiny headcount)

**Org-IT:** collections `IT-Shared-Staff` · `IT-Servers` · `IT-Breakglass`  
Groups: `IT-Users` → Shared V; `IT-Admins` → all M  

**Org-OT:** collections `OT-HMI` · `OT-PLCs` · `OT-Breakglass`  
Groups: `OT-Operators` → HMI V; `OT-Engineers` → PLCs E; `OT-Admins` → all M  