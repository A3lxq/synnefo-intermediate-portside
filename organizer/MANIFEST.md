# Organizer manifest — Portside (Intermediate)

Keep this file (and this whole `organizer/` directory) off any
player-facing host. Flag *values* are never written here — re-derive them
from the deployment's `CTF_SECRET` (HMAC-SHA256("intermediate-portside:N",
secret), first 10 hex chars, wrapped `HLC{...}`).

| # | Difficulty | Concept taught | Primary tool(s) | Where it lives |
|---|---|---|---|---|
| 1 | Easy | Reading an internal API docs page | curl/browser | HTML comment on `/docs` |
| 2 | Easy | Debug-mode source disclosure | Browser, curl | Werkzeug debugger traceback at `/manifest/abc` |
| 3 | Easy | JWT structure (decode, no crypto) | CyberChef "JWT Decode" or `jwt.decode(..., verify_signature=False)` | `/guest-token`'s own payload |
| 4 | Medium | Weak JWT secret -> forged token / auth bypass | `jwt_tool` (`-C` crack mode) or hashcat mode 16500, then forge | `/admin/dashboard` (secret: `letmein`) |
| 5 | Medium | LFI / path traversal | curl, Burp | `/reports?file=../config/secrets.txt` |
| 6 | Medium/Hard | SSRF as a network-segmentation bypass | Burp Repeater / curl | `/preview?url=http://127.0.0.1:5001/status` (port 5001 is never published) |
| 7 | Hard | Chained SSRF + OS command injection RCE | curl, URL-encoding | `/preview?url=http://127.0.0.1:5001/run?cmd=...&token=...` (token leaked via flag 5's LFI) |
| 8 | Hard | Packet capture analysis | Wireshark / `tshark -Y http` | `/incident-capture.pcap` (admin-only) |
| 9 | Hard | Credential reuse pivot | `su` (via the RCE from flag 7) | `/home/dockworker/flag9.txt` (password recovered from flag 8's pcap) |
| 10 | Hardest | Linux capability misconfiguration -> root | `getcap -r /`, then abuse `cap_setuid` | `/root/flag10.txt` |

## Honeypots (never flag-shaped, cost time only)
- `/reports?file=old_credentials.txt` — plausible but explicitly inert creds.
- SSRF to `http://127.0.0.1:5001/legacy` — a real internal endpoint that
  responds, with nothing useful behind it.

## Fixed design constants (intentional, not secret-derived)
- JWT signing secret: `letmein` (deliberately weak/guessable).
- Internal diagnostics API token: `diag-9f3a-internal` (disclosed only
  via the flag 5 LFI).
- `dockworker`'s Linux password: `H@rb0rNight92` (disclosed only via the
  flag 8 pcap).
- Privesc: `cap_setuid+ep` on the real `python3` binary (`setcap`
  misconfiguration, found via `getcap -r /`).
- Weak SSRF filter: blocks only the literal substring `localhost`
  (case-insensitive) — `127.0.0.1`, `0.0.0.0`, `[::1]` all bypass it.
