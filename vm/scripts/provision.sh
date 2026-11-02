#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="keys/ctfbuilder_ed25519"
PORT=2203
HOST="ctfbuilder@127.0.0.1"
SSH_OPTS=(-i "$KEY" -p "$PORT" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
echo "== Waiting for SSH =="
for i in $(seq 1 60); do
  if ssh "${SSH_OPTS[@]}" "$HOST" 'echo ok' >/dev/null 2>&1; then echo "SSH is up."; break; fi
  sleep 5
  [ "$i" -eq 60 ] && { echo "VM never came up over SSH after 5 minutes." >&2; exit 1; }
done
echo "== Waiting for cloud-init to fully finish =="
ssh "${SSH_OPTS[@]}" "$HOST" 'sudo cloud-init status --wait'
RELEASE_SECRET=$(cat ../organizer/release-secret.txt)
echo "== Running remote-provision.sh =="
scp -i "$KEY" -P "$PORT" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null \
  scripts/remote-provision.sh "$HOST:/tmp/remote-provision.sh"
ssh "${SSH_OPTS[@]}" "$HOST" "RELEASE_SECRET='$RELEASE_SECRET' bash /tmp/remote-provision.sh"
echo "Done. Next: ./scripts/verify.sh"
