"""
Portside — Halcyon's logistics subsidiary portal. Flask app, port 5000
(published). INTENTIONALLY VULNERABLE in several distinct ways, each
documented inline at the point of the bug.
"""
import os
import jwt
import requests
from flask import Flask, request, jsonify, Response

from generate_flags import flag_for

SECRET = os.environ["CTF_SECRET"]
# INTENTIONALLY WEAK: a short, guessable JWT signing secret -- crackable
# with jwt_tool's bundled secret list or a small rockyou-derived wordlist,
# not a brute-force-proof random value.
JWT_SECRET = "letmein"
INTERNAL_API_TOKEN = "diag-9f3a-internal"

app = Flask(__name__)
app.debug = True  # INTENTIONAL: Werkzeug's debugger shows source on unhandled exceptions


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
    # flag1: left in a comment by whoever wrote this page, same as every
    # other "temporary" internal docs page nobody ever cleans up.
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
    # flag3: lives right in the token's own payload -- decode it, don't
    # crack anything to get this one.
    token = jwt.encode(
        {"role": "guest", "note": flag("3")},
        JWT_SECRET,
        algorithm="HS256",
    )
    return jsonify({"token": token})


@app.route("/manifest/<manifest_id>")
def manifest(manifest_id):
    # Debug mode being on is the actual vulnerability -- it shows this
    # whole function's source (including the line right below) in the
    # traceback whenever manifest_id isn't an integer.
    numeric_id = int(manifest_id)  # flag2: FLAG2_PLACEHOLDER
    return jsonify({"manifest_id": numeric_id, "status": "in transit"})


@app.route("/reports")
def reports():
    # INTENTIONALLY VULNERABLE: classic path-traversal LFI. No
    # sanitization of "file" at all before joining it onto REPORTS_DIR.
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
    # INTENTIONALLY VULNERABLE: SSRF. The only "filter" is a weak,
    # trivially-bypassed substring block on the literal word "localhost"
    # -- 127.0.0.1, 0.0.0.0, and [::1] all sail straight through, and so
    # does the internal-only diagnostics API on :5001 (never published
    # to the host -- see docker-compose.yml).
    url = request.args.get("url", "")
    if "localhost" in url.lower():
        return Response("Blocked: internal URLs are not allowed.", status=400)
    try:
        resp = requests.get(url, timeout=4)
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
