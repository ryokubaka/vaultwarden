# TLS / certificates (on site)

Default pack uses Caddy `tls internal` (local CA). Browsers and Bitwarden apps will warn until clients trust that CA — or you swap to AD CS certs.

---

## Path A — GPO + Caddy root (fastest for pilot)

Use while still on `tls internal`.

1. Start the stack once so Caddy mints its CA.
2. Export the root:

   ```bash
   ./scripts/export-caddy-root.sh
   ```

   Output: `exported-ca/caddy-local-root.crt`

3. IT deploys via GPO (domain-joined Windows):

   **Computer Configuration → Policies → Windows Settings → Security Settings → Public Key Policies → Trusted Root Certification Authorities**

   Import `caddy-local-root.crt`.

4. Non-domain PCs / phones: install the root manually or via MDM. Bitwarden clients use the OS trust store — click-through in a browser is not enough for the apps.

5. Verify: browse `https://vw.org-testing.meow` with no warning; log in from Bitwarden desktop/mobile.

Same root must be trusted on any host running [Directory Connector](directory-connector.md).

---

## Path B — AD CS cert swap (preferred long-term HTTPS)

Enterprise CA already trusted by domain clients → **no Caddy root GPO**.

1. Ask IT for a Web Server certificate (or two):

   - SAN / CN: `vw.org-testing.meow`
   - Optional second cert or multi-SAN including `mail.org-testing.meow`
   - Export **private key + full chain** as PEM (or convert from PFX):

     ```bash
     openssl pkcs12 -in vw.pfx -clcerts -nokeys -out certs/vw.pem
     openssl pkcs12 -in vw.pfx -cacerts -nokeys -out certs/vw-chain.pem
     cat certs/vw.pem certs/vw-chain.pem > certs/vw-fullchain.pem && mv certs/vw-fullchain.pem certs/vw.pem
     openssl pkcs12 -in vw.pfx -nocerts -nodes -out certs/vw.key
     chmod 600 certs/vw.key
     ```

     Repeat for `mail.*` or reuse a multi-SAN pair as both `vw.*` and `mail.*`.

2. Place files under `./certs/` (mounted read-only at `/certs` in Caddy):

   - `certs/vw.pem`, `certs/vw.key`
   - `certs/mail.pem`, `certs/mail.key`

3. Switch Caddy config:

   ```bash
   cp Caddyfile.adcs.example Caddyfile
   docker compose up -d caddy
   ```

4. Confirm with a domain-joined browser (no warning). Remove any temporary Caddy-root GPO if you added Path A.

**AD CS signs TLS only** — not email. For invites, see [smtp.md](smtp.md).

No Let's Encrypt in this pack (private / fake `org-testing.meow` domain).
