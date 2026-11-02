# Tools you'll use in this box

| Tool | What it's for here |
|---|---|
| curl / browser | Read the docs page, trigger the debug traceback. |
| CyberChef "JWT Decode" or `jwt.decode(verify_signature=False)` | Read a JWT's payload without needing its secret (flag 3). |
| `jwt_tool` (crack mode) or hashcat mode 16500 | Crack a weak HS256 JWT signing secret, then forge a token with a different `role` claim (flag 4). |
| Burp Suite / curl | Craft the LFI path-traversal request (flag 5) and the SSRF requests (flags 6, 7). |
| URL encoding | The SSRF target URL itself needs its own query string (`cmd=`, `token=`) URL-encoded inside the outer `url=` parameter. |
| Wireshark or `tshark -Y http` | Inspect a provided packet capture for cleartext credentials and data (flag 8). |
| `su` | Switch to another Linux account once you have its (reused) password (flag 9). |
| `getcap -r / 2>/dev/null` | Find a binary with a dangerous Linux capability set (flag 10). |
