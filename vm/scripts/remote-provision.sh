#!/usr/bin/env bash
# remote-provision.sh — runs INSIDE the guest. Native build: real
# Python/Flask services managed by systemd, no Docker. The app itself
# is unchanged -- app.py (0.0.0.0:5000, published) and diag.py
# (127.0.0.1:5001, loopback-only -- reachable only via app.py's own
# SSRF-vulnerable /preview, exactly as faithfully as the Docker version
# where it was simply never published) both still read CTF_SECRET from
# the environment. Entirely self-contained; idempotent.
set -euo pipefail

: "${RELEASE_SECRET:?RELEASE_SECRET must be passed in (never hardcode it here -- this script is public)}"
DOCKWORKER_PASSWORD="H@rb0rNight92"   # only ever disclosed via the pcap (flag 8)

echo "== Python venv + deps =="
sudo mkdir -p /opt/venv
sudo python3 -m venv /opt/venv
sudo /opt/venv/bin/pip install -q --no-cache-dir --retries 10 --timeout 120 \
    flask==3.1.0 pyjwt==2.9.0 requests==2.32.3 scapy==2.6.1

echo "== Laying out the app under /opt/portside/app =="
sudo mkdir -p /opt/portside/app /opt/portside/reports /opt/portside/config

sudo tee /opt/portside/app/generate_flags.py >/dev/null <<'PY_EOF'
import hmac
import hashlib

BOX_ID = "intermediate-portside"


def flag_for(secret: str, n: int) -> str:
    digest = hmac.new(secret.encode(), f"{BOX_ID}:{n}".encode(), hashlib.sha256).hexdigest()
    return f"HLC{{{digest[:10]}}}"
PY_EOF

sudo tee /opt/portside/app/app.py >/dev/null <<'PY_EOF'
import os
import jwt
import requests
from flask import Flask, request, jsonify, Response

from generate_flags import flag_for

SECRET = os.environ["CTF_SECRET"]
JWT_SECRET = "letmein"
INTERNAL_API_TOKEN = "diag-9f3a-internal"

app = Flask(__name__)
app.debug = True


def flag(n):
    return flag_for(SECRET, n)


def require_role(role):
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[len("Bearer "):]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except Exception:
        return None
    if payload.get("role") != role:
        return None
    return payload


@app.route("/")
def index():
    return """<!DOCTYPE html><html><head><title>Portside</title></head><body>
    <h1>Portside — Halcyon Logistics</h1>
    <p>Shipment tracking and manifest portal. See <a href="/docs">API docs</a>,
    or request a <a href="/guest-token">guest token</a> to explore the API.</p>
    </body></html>"""


@app.route("/docs")
def docs():
    return f"""<!DOCTYPE html><html><head><title>Portside API Docs</title></head>
    <body>
    <!-- {flag("1")} -->
    <h1>Portside API (internal)</h1>
    <ul>
      <li><code>GET /guest-token</code> — issue a guest JWT</li>
      <li><code>GET /manifest/&lt;id&gt;</code> — look up a shipment manifest by numeric id</li>
      <li><code>GET /reports?file=...</code> — download a named report from the reports/ folder</li>
      <li><code>GET /preview?url=...</code> — preview an external label image URL before attaching it to a manifest</li>
      <li><code>GET /admin/dashboard</code> — admin only (Bearer JWT, role=admin)</li>
    </ul>
    </body></html>"""


@app.route("/guest-token")
def guest_token():
    token = jwt.encode(
        {"role": "guest", "note": flag("3")},
        JWT_SECRET,
        algorithm="HS256",
    )
    return jsonify({"token": token})


@app.route("/manifest/<manifest_id>")
def manifest(manifest_id):
    numeric_id = int(manifest_id)  # flag2: FLAG2_PLACEHOLDER
    return jsonify({"manifest_id": numeric_id, "status": "in transit"})


@app.route("/reports")
def reports():
    reports_dir = "/opt/portside/reports"
    filename = request.args.get("file", "")
    path = os.path.join(reports_dir, filename)
    try:
        with open(path, "r", errors="replace") as f:
            return Response(f.read(), mimetype="text/plain")
    except Exception as e:
        return Response(f"Could not read report: {e}", status=404, mimetype="text/plain")


@app.route("/preview")
def preview():
    url = request.args.get("url", "")
    if "localhost" in url.lower():
        return Response("Blocked: internal URLs are not allowed.", status=400)
    try:
        # Generous timeout: the RUN command this proxies to (including
        # a `su` call, which carries real PAM session-setup overhead)
        # can legitimately take several seconds on slower hardware --
        # confirmed 18s+ for a single `su` under heavy VM emulation.
        resp = requests.get(url, timeout=25)
        return Response(resp.text[:4000], mimetype="text/plain")
    except Exception as e:
        return Response(f"Fetch failed: {e}", status=502, mimetype="text/plain")


@app.route("/admin/dashboard")
def admin_dashboard():
    if not require_role("admin"):
        return Response("403 — admin JWT required.", status=403)
    return f"""<!DOCTYPE html><html><head><title>Admin</title></head><body>
    <h1>Admin Dashboard</h1>
    <p>{flag("4")}</p>
    <p>See also: <a href="/incident-capture.pcap">incident-capture.pcap</a>
    (last week's flagged traffic, forwarded by the SOC).</p>
    </body></html>"""


@app.route("/incident-capture.pcap")
def incident_capture():
    if not require_role("admin"):
        return Response("403 — admin JWT required.", status=403)
    pcap_path = "/opt/portside/incident-capture.pcap"
    try:
        with open(pcap_path, "rb") as f:
            return Response(f.read(), mimetype="application/vnd.tcpdump.pcap")
    except Exception as e:
        return Response(f"Could not read capture: {e}", status=404)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
PY_EOF

sudo tee /opt/portside/app/diag.py >/dev/null <<'PY_EOF'
import os
import subprocess

from flask import Flask, request, Response

from generate_flags import flag_for

SECRET = os.environ["CTF_SECRET"]
INTERNAL_API_TOKEN = "diag-9f3a-internal"

app = Flask(__name__)


@app.route("/status")
def status():
    return f"status: ok\nnote: {flag_for(SECRET, 6)}\n"


@app.route("/legacy")
def legacy():
    return "This endpoint was deprecated in 2021 and decommissioned. There's nothing here.\n"


@app.route("/run")
def run():
    token = request.args.get("token", "")
    if token != INTERNAL_API_TOKEN:
        return Response("403 — invalid internal token.", status=403)
    cmd = request.args.get("cmd", "echo no command given")
    try:
        out = subprocess.run(cmd, shell=True, capture_output=True, timeout=20, text=True)
        return Response(out.stdout + out.stderr, mimetype="text/plain")
    except Exception as e:
        return Response(f"error: {e}", status=500, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001)
PY_EOF

sudo tee /opt/portside/app/make_pcap.py >/dev/null <<'PY_EOF'
import sys

from scapy.all import Ether, IP, TCP, wrpcap
from generate_flags import flag_for


def build(secret: str, dockworker_password: str, out_path: str):
    flag8 = flag_for(secret, 8)
    body = (
        f"POST /internal/handoff HTTP/1.1\r\n"
        f"Host: portside-legacy.internal\r\n"
        f"Content-Type: application/x-www-form-urlencoded\r\n"
        f"\r\n"
        f"note={flag8}&dockworker_password={dockworker_password}\r\n"
    ).encode()

    pkt = (
        Ether(src="02:00:00:00:00:01", dst="02:00:00:00:00:02")
        / IP(src="10.40.0.21", dst="10.40.0.5")
        / TCP(sport=51514, dport=80, flags="PA", seq=1, ack=1)
        / body
    )
    wrpcap(out_path, [pkt])


if __name__ == "__main__":
    secret, pw, out = sys.argv[1], sys.argv[2], sys.argv[3]
    build(secret, pw, out)
    print(f"Wrote {out}")
PY_EOF

sudo tee /opt/portside/reports/manifest1.pdf >/dev/null <<'EOF'
(placeholder -- a real deployment would have an actual PDF here)
Shipment #1 manifest: 40 pallets, routed via Portside terminal 3.
EOF
sudo tee /opt/portside/reports/old_credentials.txt >/dev/null <<'EOF'
rotated out after the 2022 incident, do not bother -- these work nowhere:
ops_legacy / Sh1pment$2022
backup_svc / Portside_Backup!
EOF

echo "== Patching flag2 into app.py's own crash-line comment =="
getflag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/portside/app'); from generate_flags import flag_for; print(flag_for('$RELEASE_SECRET', $1))"; }
F2=$(getflag 2)
sudo sed -i "s/FLAG2_PLACEHOLDER/$F2/" /opt/portside/app/app.py

echo "== Internal config (flag5 + the diag API token, LFI target) =="
F5=$(getflag 5)
sudo tee /opt/portside/config/secrets.txt >/dev/null <<EOF
# internal config -- not linked from anywhere, not meant to be web-reachable
INTERNAL_API_TOKEN=diag-9f3a-internal
NOTE=leftover from the 2023 migration, scheduled for deletion, nobody did
FLAG=$F5
EOF

echo "== flag7: reachable only through the diag API's command injection =="
getflag 7 | sudo tee /opt/portside/flag7.txt >/dev/null
sudo chmod 644 /opt/portside/flag7.txt

echo "== Building the incident-capture.pcap (flag8 + dockworker password) =="
sudo /opt/venv/bin/python3 /opt/portside/app/make_pcap.py "$RELEASE_SECRET" "$DOCKWORKER_PASSWORD" /opt/portside/incident-capture.pcap
sudo chmod 644 /opt/portside/incident-capture.pcap

echo "== dockworker account (flag9, credential reuse via the pcap) =="
sudo id -u dockworker >/dev/null 2>&1 || sudo useradd -m -s /bin/bash dockworker
echo "dockworker:$DOCKWORKER_PASSWORD" | sudo chpasswd
getflag 9 | sudo tee /home/dockworker/flag9.txt >/dev/null
sudo chown dockworker:dockworker /home/dockworker/flag9.txt
sudo chmod 600 /home/dockworker/flag9.txt

echo "== Linux capability misconfig -> root (flag10) =="
REAL_PY=$(readlink -f /usr/bin/python3)
sudo setcap cap_setuid+ep "$REAL_PY"
sudo getcap "$REAL_PY"
getflag 10 | sudo tee /root/flag10.txt >/dev/null
sudo chmod 600 /root/flag10.txt

sudo chown -R root:root /opt/portside
sudo find /opt/portside -type d -exec chmod 755 {} +
sudo find /opt/portside -type f -exec chmod 644 {} +

echo "== systemd units =="
sudo tee /etc/systemd/system/portside-app.service >/dev/null <<EOF
[Unit]
Description=Portside app (public, port 5000)
After=network.target

[Service]
Type=simple
ExecStart=/opt/venv/bin/python3 /opt/portside/app/app.py
WorkingDirectory=/opt/portside/app
Environment=CTF_SECRET=$RELEASE_SECRET
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/portside-diag.service >/dev/null <<EOF
[Unit]
Description=Portside internal diagnostics API (loopback-only, port 5001)
After=network.target

[Service]
Type=simple
ExecStart=/opt/venv/bin/python3 /opt/portside/app/diag.py
WorkingDirectory=/opt/portside/app
Environment=CTF_SECRET=$RELEASE_SECRET
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable portside-app portside-diag
sudo systemctl restart portside-app portside-diag

echo "== Restarting ssh (clearing any stray listeners first) =="
sudo pkill -9 -f 'sshd: /usr/sbin/sshd -D \[listener\]' 2>/dev/null || true
sleep 1
sudo systemctl restart ssh
sudo systemctl enable ssh

echo "Done."
