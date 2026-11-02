"""
Builds a small, genuinely-valid pcap (no live capture, no raw sockets
needed) containing one HTTP request whose body carries flag8 and a
cleartext password for the 'dockworker' Linux account -- meant to be
found with Wireshark/tshark, then reused to `su dockworker`.
"""
import sys

from scapy.all import Ether, IP, TCP, wrpcap
from generate_flags import flag_for


def build(secret: str, dockworker_password: str, out_path: str):
    flag8 = flag_for(secret, 8)
    body = (
        f"POST /internal/handoff HTTP/1.1\r\n"
        f"Host: portside-legacy.internal\r\n"
        f"Content-Type: application/x-www-form-urlencoded\r\n"
        f"\r\n"
        f"note={flag8}&dockworker_password={dockworker_password}\r\n"
    ).encode()

    pkt = (
        Ether(src="02:00:00:00:00:01", dst="02:00:00:00:00:02")
        / IP(src="10.40.0.21", dst="10.40.0.5")
        / TCP(sport=51514, dport=80, flags="PA", seq=1, ack=1)
        / body
    )
    wrpcap(out_path, [pkt])


if __name__ == "__main__":
    secret, pw, out = sys.argv[1], sys.argv[2], sys.argv[3]
    build(secret, pw, out)
    print(f"Wrote {out}")
