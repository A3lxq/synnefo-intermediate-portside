# Hints (progressive — try to only read as far as you need)

**Flag 1** — Read `/docs`, including its page source.

**Flag 2** — The docs page mentions `/manifest/<id>` expects a numeric id.
What happens if you give it something that isn't a number, and what does
the error page show you?

**Flag 3** — `/guest-token` hands you a JWT. A JWT's payload (the middle
of its three dot-separated parts) is just base64url — you don't need the
signing secret to read it, only to forge a NEW one.

**Flag 4** — The signing secret is short and guessable, not
brute-force-proof. Once you have it, you can mint your own token with any
claims you like — including a role nothing legitimately hands out.

**Flag 5** — `/reports?file=...` reads a file relative to a reports
folder with no path sanitization at all. What's next to that folder that
might be worth reading?

**Flag 6** — `/preview?url=...` fetches a URL server-side. Its filter
only blocks one specific word. There's more than one way to write
"localhost."

**Flag 7** — The internal service you just reached (via SSRF) has a
second endpoint that runs a command — but it wants a token. You already
found one, reading a file you weren't supposed to reach, back in flag 5.

**Flag 8** — There's a downloadable capture file, admin-only. Open it in
Wireshark (or `tshark -Y http`) and follow the stream.

**Flag 9** — The capture didn't just have a flag in it.

**Flag 10** — Once you have command execution (from flag 7's chain), look
for Linux capabilities, not just SUID bits: `getcap -r / 2>/dev/null`.
