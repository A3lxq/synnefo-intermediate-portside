# VM / OVA — Portside

Guest OS: **Ubuntu Server 24.04 LTS** (official cloud image), via
QEMU/KVM + cloud-init (NoCloud). Native build — real Python/Flask
services managed by systemd, no Docker anywhere.

Two services, both unchanged in design from the original: `app.py`
(0.0.0.0:5000, published) and `diag.py` (127.0.0.1:5001, **loopback-only**
— reachable only via `app.py`'s own SSRF-vulnerable `/preview` endpoint,
just as faithfully as the original Docker build where it was simply
never published).

Flags are **static**, baked in once at provisioning time from a fixed
release secret — every copy of the exported OVA has the same flags.
The release secret is never committed; `organizer/release-secret.txt`
(gitignored) holds it.

## Build from source

```
cd vm
# put ubuntu-24.04-server-cloudimg-amd64.img in images/ first
# put your own ed25519 keypair in keys/ctfbuilder_ed25519[.pub],
# and reference the .pub in cloud-init/user-data.yaml
# generate a release secret: openssl rand -hex 32 > ../organizer/release-secret.txt
./scripts/create-disk.sh
./scripts/boot-vm.sh      # wait a few minutes for first boot + cloud-init
./scripts/provision.sh
./scripts/verify.sh       # proves all 10 flags before you export anything
./scripts/export-vm.sh
./scripts/export-ova.sh
```

## Using the pre-built OVA

Download the `.ova` from this repo's Releases page, then File > Import
Appliance in VirtualBox (or Open in VMware Workstation/Fusion). Power
it on and wait for boot (a minute or so) — everything is already set
up. Browse to port 5000.

**This is an intentionally vulnerable machine. Import it only on an
isolated network.**

## Build note

The `/preview` SSRF proxy and the internal `/run` command endpoint both
use generous timeouts (25s / 20s) — a single `su` call carries real PAM
session-setup overhead that can run into double-digit seconds on slow
or heavily-virtualized hardware. If you rebuild this and see flag 9 time
out, that's the symptom; don't shrink these back down.
