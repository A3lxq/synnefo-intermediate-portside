# Case File 3 (Intermediate) — Portside

Part of **The Halcyon Protocol** CTF series. This box stands alone — you do
not need any other box in the series to play it.

> See [`STORY.md`](STORY.md) for the full case file.

## What this is

A single deliberately-vulnerable Flask application (plus a never-published
internal API) aimed at players comfortable with web basics who want to go
further: JWT handling, SSRF, LFI, chained exploitation, traffic-capture
analysis, credential reuse, and a Linux capability misconfiguration. 10
flags, no decoys. The first three are easy; difficulty then climbs
steeply, and several later flags depend on earlier ones.

**This machine is intentionally vulnerable. Run it only on an isolated
network.**

## Status

This box ships as a VM appliance (OVA) — see the `vm/` directory once it's
built. There is no Docker build in this repo (an earlier Docker build was
removed; a Docker version may be added back separately).

## Flag format

`HLC{xxxxxxxxxx}` — submit exactly as found.

## Rules

- No decoy flags: everything matching the flag format is real and counts.
- Some things in this box are honeypots — red herrings that cost you time,
  not flags.
- Don't attack this box over a shared or public network.

## More

- [`STORY.md`](STORY.md) — the in-universe case file
- [`docs/hints.md`](docs/hints.md) — progressive hints
- [`docs/tools.md`](docs/tools.md) — what each tool is for
- [`docs/writeup/WRITEUP.md`](docs/writeup/WRITEUP.md) — full spoiler walkthrough
- [`flags/generate_flags.py`](flags/generate_flags.py) — the per-deployment flag derivation scheme, used by `organizer/verify.py`
