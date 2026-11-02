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

## Requirements

- Docker + Docker Compose
- A player machine with: `curl`, Burp Suite Community (or equivalent),
  `jwt_tool` or CyberChef (JWT decode/crack), Wireshark or `tshark`,
  Python 3 with `pyjwt` (handy for scripting the later steps)

## Starting the box

```
./start.sh
```
Generates a fresh `.env` with a random per-deployment secret and brings the
stack up.

- Web: http://localhost:8003

Note: this app also runs a second, internal-only API on port 5001 that is
**never published** by `docker-compose.yml` — that's intentional, and part
of the challenge (see flag 6).

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
