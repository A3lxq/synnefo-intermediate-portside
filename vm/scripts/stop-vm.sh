#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PIDFILE="disks/vm.pid"
if [ ! -f "$PIDFILE" ]; then
  echo "No pidfile -- VM not running (or already stopped)." >&2
  exit 0
fi
PID=$(cat "$PIDFILE")
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  for i in $(seq 1 20); do
    kill -0 "$PID" 2>/dev/null || break
    sleep 1
  done
fi
rm -f "$PIDFILE"
echo "Stopped."
