#!/usr/bin/env bash
# boot-vm.sh — starts this box's VM in the background, host-only
# networking (QEMU user-mode NAT). Only SSH (for build/provisioning) is
# forwarded to the host -- the box's own services are reached by SSHing
# in and testing against localhost there, or (for real play, once this
# VM is exported as an OVA) via whatever networking the importing
# hypervisor is configured with.
set -euo pipefail
cd "$(dirname "$0")/.."

DISK="disks/intermediate-portside.qcow2"
SEED="seed/seed.img"
PIDFILE="disks/vm.pid"
MONITOR="disks/monitor.sock"
LOG="logs/vm-console.log"
SSH_PORT=2203

if [ ! -f "$DISK" ] || [ ! -f "$SEED" ]; then
  echo "Missing $DISK or $SEED. Run ./scripts/create-disk.sh first." >&2
  exit 1
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "VM already running (pid $(cat "$PIDFILE"))." >&2
  exit 1
fi

mkdir -p logs

ACCEL="tcg"
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL="kvm"
fi
echo "Using acceleration: $ACCEL"

qemu-system-x86_64 \
  -name intermediate-portside \
  -machine type=q35,accel=$ACCEL \
  -cpu max \
  -m 1024 \
  -smp 2 \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -drive file="$SEED",if=virtio,format=raw \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22,hostfwd=tcp:127.0.0.1:8003-:5000 \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -serial file:"$LOG" \
  -monitor unix:"$MONITOR",server,nowait \
  -pidfile "$PIDFILE" \
  -daemonize

echo "VM starting (pid $(cat "$PIDFILE"))."
echo "Console log: vm/$LOG"
echo "SSH (build/provisioning only): ssh -i keys/ctfbuilder_ed25519 -p $SSH_PORT ctfbuilder@127.0.0.1"
echo "Stop with: ./scripts/stop-vm.sh"
