#!/bin/bash
set -euo pipefail

: "${CTF_SECRET:?CTF_SECRET must be set (see start.sh / .env)}"
export CTF_SECRET

DOCKWORKER_PASSWORD="H@rb0rNight92"  # only ever disclosed via the pcap (flag 8)

mkdir -p /var/log/supervisor /opt/portside/config /opt/portside/reports
cp /opt/app/reports/*.pdf /opt/app/reports/*.txt /opt/portside/reports/ 2>/dev/null || true

VENV=/opt/venv
getflag() { $VENV/bin/python3 -c "import sys; sys.path.insert(0,'/opt/app'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', $1))"; }

F2=$(getflag 2)
sed -i "s/FLAG2_PLACEHOLDER/$F2/" /opt/app/app.py

F5=$(getflag 5)

cat > /opt/portside/config/secrets.txt <<EOF
# internal config -- not linked from anywhere, not meant to be web-reachable
INTERNAL_API_TOKEN=diag-9f3a-internal
NOTE=leftover from the 2023 migration, scheduled for deletion, nobody did
FLAG=$F5
EOF

# Reachable only through the diag API's command injection (flag 7's RCE),
# never directly over HTTP.
getflag 7 > /opt/portside/flag7.txt
chmod 644 /opt/portside/flag7.txt

$VENV/bin/python3 /opt/app/make_pcap.py "$CTF_SECRET" "$DOCKWORKER_PASSWORD" /opt/portside/incident-capture.pcap
chmod 644 /opt/portside/incident-capture.pcap

echo "dockworker:$DOCKWORKER_PASSWORD" | chpasswd
getflag 9 > /home/dockworker/flag9.txt
chown dockworker:dockworker /home/dockworker/flag9.txt
chmod 600 /home/dockworker/flag9.txt

getflag 10 > /root/flag10.txt
chmod 600 /root/flag10.txt

echo "[entrypoint] Portside ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
