#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DISK="disks/intermediate-portside.qcow2"
OUT_DIR="dist"
OUT_IMAGE="$OUT_DIR/intermediate-portside-ctf.qcow2"
if [ ! -f "$DISK" ]; then echo "Missing $DISK. Build the VM first." >&2; exit 1; fi
echo "== Stopping the VM =="
./scripts/stop-vm.sh
echo "== Snapshotting this verified, ready-to-play state =="
qemu-img snapshot -d clean-start "$DISK" 2>/dev/null || true
qemu-img snapshot -c clean-start "$DISK"
mkdir -p "$OUT_DIR"
echo "== Flattening =="
rm -f "$OUT_IMAGE"
qemu-img convert -l clean-start -O qcow2 -c "$DISK" "$OUT_IMAGE"
(cd "$OUT_DIR" && sha256sum "$(basename "$OUT_IMAGE")" > SHA256SUMS)
echo "== Restarting the source VM =="
./scripts/boot-vm.sh
echo "Done. Next: ./scripts/export-ova.sh"
ls -lh "$OUT_DIR"
