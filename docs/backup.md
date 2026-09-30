# Backups (NAS) — offen/docker-volume-backup

Uses [offen/docker-volume-backup](https://github.com/offen/docker-volume-backup) to tar Vaultwarden (+ Caddy PKI, optional emailproxy tokens) on a schedule and store archives on a **NAS**.

Docs: [offen documentation](https://offen.github.io/docker-volume-backup/).

## What gets backed up

| Host path | In archive as | Why |
|-----------|---------------|-----|
| `./data` | `vaultwarden/` | SQLite DB, attachments, `config.json`, RSA keys |
| `./caddy-data` | `caddy-data/` | TLS / local CA material |
| `./emailproxy` | `emailproxy/` | OAuth token cache (if you use Option 2 SMTP) |
| this repo (minus `data/` / `backups/`) | `code/app/` | Compose, `.env`, scripts — enough to start the stack again |
| sibling `utility-support` | `code/utility-support/` | `stacks`, proxy TLS, plant overrides |

During backup, **Vaultwarden is stopped** briefly (`docker-volume-backup.stop-during-backup`) so SQLite is consistent, then restarted. `stacks backup vaultwarden` refreshes `.backup-code` (compose, `.env`, utility-support) immediately before the tar. The sidecar cron uses whatever is already in that folder.

## Enable

```bash
cp backup.env.example backup.env
# edit schedule / retention / SSH if needed

# Point archives at a NAS mount (recommended) or leave default ./backups
# In .env:
#   NAS_BACKUP_PATH=/mnt/nas/vaultwarden-backups

docker compose --profile backup up -d
docker compose logs -f backup
```

One-off run inside the sidecar (same `/archive` mount). A `compose run`
one-shot often has no `/archive`, so offen writes the tar to `/tmp` and
deletes it. You should see `Stored copy of backup … in /archive`.

```bash
stacks backup vaultwarden
# or from this directory:
docker compose --profile backup up -d
docker exec vw-backup /usr/bin/backup
```

---

## NAS target — pick one

### A) Host mount (recommended for plant NAS)

1. On the Docker host, mount the NAS share (examples):

   **NFS**

   ```bash
   sudo mkdir -p /mnt/nas/vaultwarden-backups
   # fstab example:
   # nas.plant.local:/volume1/vw-backups  /mnt/nas/vaultwarden-backups  nfs  defaults,_netdev  0  0
   sudo mount /mnt/nas/vaultwarden-backups
   ```

   **CIFS/SMB**

   ```bash
   sudo mkdir -p /mnt/nas/vaultwarden-backups
   # fstab example (creds in /etc/nas-credentials, chmod 600):
   # //nas.plant.local/vw-backups  /mnt/nas/vaultwarden-backups  cifs  credentials=/etc/nas-credentials,uid=0,gid=0,iocharset=utf8,_netdev  0  0
   sudo mount /mnt/nas/vaultwarden-backups
   ```

2. In `.env`:

   ```env
   NAS_BACKUP_PATH=/mnt/nas/vaultwarden-backups
   ```

3. `docker compose --profile backup up -d`

Archives appear on the NAS as `vw-YYYY-mm-ddTHH-MM-SS.tar.gz` plus symlink `vw.latest.tar.gz` (if enabled in `backup.env`). Older archives may still be named `vw-portable-…`.

No SSH keys in the container. Host mount permissions must allow the backup container to write (often root on the mount).

### B) SSH/SFTP to the NAS

If you cannot mount the share on the host:

1. Create a NAS user with write access to a backup folder; install an SSH public key.
2. Put the private key in `./backup-ssh/` (gitignored) and mount it (already wired in compose when present — see `docker-compose.yml`).
3. In `backup.env`:

   ```env
   SSH_HOST_NAME=nas.plant.local
   SSH_PORT=22
   SSH_USER=vwbackup
   SSH_REMOTE_PATH=/volume1/backups/vaultwarden
   SSH_IDENTITY_FILE=/root/.ssh/id_ed25519
   ```

4. You can still keep a local `/archive` (host `NAS_BACKUP_PATH` or `./backups`) **and** push SSH — offen supports multiple backends.

---

## Retention & schedule

Defaults in `backup.env.example`:

- Cron: `15 2 * * *` (02:15 daily)
- Retention: **30 days** (`BACKUP_RETENTION_DAYS`)

Adjust in `backup.env`, then recreate the backup service.

---

## Restore

Use the same offen image as `vw-backup`. The `restore` service remounts `/backup` writable and extracts the archive into those mounts. Do not rsync from the host.

1. Stop the stack so SQLite is not open (`stacks down vaultwarden`, or `docker compose down` from this directory with the utility-support override).
2. List archives the backup container can see:

   ```bash
   docker exec vw-backup ls -lt /archive
   docker exec vw-backup tar -tzf /archive/vw.latest.tar.gz
   ```

3. Restore the latest symlink (default) or a named archive. Prefer `stacks` so the utility-support override stays on and `code/` is written back onto the host:

   ```bash
   stacks restore vaultwarden

   RESTORE_ARCHIVE=/archive/vw-YYYY-mm-ddTHH-MM-SS.tar.gz \
     stacks restore vaultwarden
   ```

   If the Docker VM is gone, extract the trees from the NAS archive first, then recover data:

   ```bash
   tar -xzf /mnt/nas/vaultwarden-backups/vw.latest.tar.gz --wildcards '*/extract-code.py'
   python3 backup/code/extract-code.py /mnt/nas/vaultwarden-backups/vw.latest.tar.gz --dest /opt
   cd /opt/utility-support && sudo ./stacks install
   stacks recover vaultwarden /mnt/nas/vaultwarden-backups/vw.latest.tar.gz
   ```

   From this directory without `stacks`:

   ```bash
   docker compose --profile restore run --rm restore

   RESTORE_ARCHIVE=/archive/vw-YYYY-mm-ddTHH-MM-SS.tar.gz \
     docker compose --profile restore run --rm restore
   ```

   Offen archives store `/backup/vaultwarden/…`. The script maps that onto the live `data/` mount. It refuses if that tree is missing.
4. Start the stack (`stacks up vaultwarden`).
5. Verify login + Admin diagnostics.

`caddy-data/` in the archive is leftover from the app-repo Caddy. The restore service does not write it back.

Practice a restore once before go-live.

---

## Security notes

- Backup archives contain **vault ciphertext + server keys** — treat like production secrets. Restrict NAS share ACLs; prefer encryption at rest on the NAS or `BACKUP_GPG_PASSPHRASE`.
- `backup` mounts `docker.sock` (read-only) so it can stop/start Vaultwarden — limit who can control that compose project.
- Do not commit `backup.env` or SSH private keys.

---

## Image pin

Backup image is pinned in `docker-compose.yml` (e.g. `offen/docker-volume-backup:v2.48.2`). Bump deliberately when you upgrade; see [releases](https://github.com/offen/docker-volume-backup/releases).
