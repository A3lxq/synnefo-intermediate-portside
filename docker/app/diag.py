"""
Internal diagnostics API. Deliberately never published in
docker-compose.yml — only reachable from inside the container (i.e. via
the main app's SSRF-vulnerable /preview endpoint), on purpose, to teach
SSRF as a network-segmentation bypass.
"""
import os
import subprocess

from flask import Flask, request, Response

from generate_flags import flag_for

SECRET = os.environ["CTF_SECRET"]
INTERNAL_API_TOKEN = "diag-9f3a-internal"  # also disclosed via the LFI (flag 5's config.txt)

app = Flask(__name__)


@app.route("/status")
def status():
    # flag6: no token needed for the basic status check -- SSRF alone
    # (reaching 127.0.0.1:5001 from inside the container) is enough.
    return f"status: ok\nnote: {flag_for(SECRET, 6)}\n"


@app.route("/legacy")
def legacy():
    # Honeypot: a plausible-looking internal endpoint, reachable via the
    # same SSRF pivot as /status and /run, with nothing behind it.
    return "This endpoint was deprecated in 2021 and decommissioned. There's nothing here.\n"


@app.route("/run")
def run():
    # INTENTIONALLY VULNERABLE: OS command injection, string-built,
    # shell=True, gated only by a fixed internal token (itself disclosed
    # via the LFI in flag 5 -- this endpoint is meant to require BOTH the
    # SSRF pivot AND that leaked token, chaining two separate bugs).
    token = request.args.get("token", "")
    if token != INTERNAL_API_TOKEN:
        return Response("403 — invalid internal token.", status=403)
    cmd = request.args.get("cmd", "echo no command given")
    try:
        out = subprocess.run(cmd, shell=True, capture_output=True, timeout=5, text=True)
        return Response(out.stdout + out.stderr, mimetype="text/plain")
    except Exception as e:
        return Response(f"error: {e}", status=500, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001)
