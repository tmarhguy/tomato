#!/usr/bin/env python3
"""Least-friction LAN API for Tomato Ethernet bring-up (no deps, stdlib only).

The board top overrides the simulation module with a static config (default 10.0.0.250:5000, see
hardware/fpga/ethernet_test/rtl/ethernet_top.v): it answers ARP for its IP,
echoes any UDP datagram sent to port 5000 back to the sender, and
broadcasts "TOMATO HELLO <ctr> IP=<hex>" every ~5s. This tool is the other
half: discover the board, send it a message, verify the echo.

  python3 tools/tomato_lan.py listen                 # see HELLOs + any traffic
  python3 tools/tomato_lan.py hello-wait             # wait for one HELLO, print FPGA IP
  python3 tools/tomato_lan.py send "hello tomato"    # send, wait for echo, check match

If your router is not 10.0.0.x, pass --fpga-ip to match the rebuilt
FPGA_IP parameter (one line in lan_min.v). No DHCP/DNS/TCP/TLS anywhere.
"""
import argparse
import socket
import sys
import time

PORT_DEFAULT = 5000


def open_listener(port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    except (AttributeError, OSError):
        pass
    sock.bind(("0.0.0.0", port))
    return sock


def preview(data):
    try:
        text = data.decode("ascii")
        if all(32 <= ord(ch) < 127 or ch in "\r\n\t" for ch in text):
            return repr(text)
    except UnicodeDecodeError:
        pass
    return "%d bytes hex=%s" % (len(data), data[:32].hex())


def cmd_listen(args):
    sock = open_listener(args.port)
    sock.settimeout(0.5)
    print("listening on 0.0.0.0:%d (Ctrl-C to stop)" % args.port, flush=True)
    while True:
        try:
            data, addr = sock.recvfrom(2048)
        except socket.timeout:
            continue
        print("RX %s:%d %s" % (addr[0], addr[1], preview(data)), flush=True)


def parse_hello(data):
    try:
        text = data.decode("ascii")
    except UnicodeDecodeError:
        return None
    if not text.startswith("TOMATO HELLO "):
        return None
    tag = " IP="
    if tag not in text:
        return None
    hexip = text.split(tag)[1].strip()[:8]
    try:
        raw = bytes.fromhex(hexip)
    except ValueError:
        return None
    if len(raw) != 4:
        return None
    return ".".join(str(b) for b in raw)


def cmd_hello_wait(args):
    sock = open_listener(args.port)
    sock.settimeout(1.0)
    deadline = time.monotonic() + args.timeout
    print("waiting for TOMATO HELLO on port %d ..." % args.port, flush=True)
    while time.monotonic() < deadline:
        try:
            data, addr = sock.recvfrom(2048)
        except socket.timeout:
            continue
        print("RX %s:%d %s" % (addr[0], addr[1], preview(data)), flush=True)
        ip = parse_hello(data)
        if ip is not None:
            print("TOMATO AT %s (observed %s:%d)" % (ip, addr[0], addr[1]), flush=True)
            return 0
    print("no HELLO within %ds" % args.timeout, file=sys.stderr)
    return 1


def cmd_send(args):
    payload = args.text.encode("utf-8")
    if not 1 <= len(payload) <= 512:
        print("message must be 1-512 bytes", file=sys.stderr)
        return 2
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(args.timeout)
    dest = (args.fpga_ip, args.port)
    sock.connect(dest)  # kernel filters replies from other addresses/ports
    for attempt in range(1, args.retries + 1):
        sock.send(payload)
        try:
            data, addr = sock.recvfrom(2048)
        except socket.timeout:
            print("attempt %d: no reply, retrying..." % attempt, flush=True)
            continue
        print("reply %s:%d %s" % (addr[0], addr[1], preview(data)), flush=True)
        if data == payload:
            print("ECHO OK (%d bytes)" % len(data))
            return 0
        print("payload mismatch", file=sys.stderr)
        return 1
    print("no reply after %d attempts" % args.retries, file=sys.stderr)
    return 1


def cmd_verify(args):
    """Fresh binary challenges prevent stale echoes passing as a new delivery."""
    import secrets
    lengths = (0, 1, 2, 9, 40, 95, 256, 511, 512)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(args.timeout)
        sock.connect((args.fpga_ip, args.port))
        for cycle in range(args.rounds):
            for n in lengths:
                payload = secrets.token_bytes(n)
                ok = False
                for attempt in range(args.retries):
                    sock.send(payload)
                    deadline = time.monotonic() + args.timeout
                    while time.monotonic() < deadline:
                        sock.settimeout(max(.001, deadline-time.monotonic()))
                        try: reply = sock.recv(2048)
                        except socket.timeout: break
                        if reply == payload: ok = True; break
                    if ok: break
                if not ok:
                    print(f'FAIL round={cycle+1} size={n}', flush=True)
                    return 1
                print(f'PASS round={cycle+1} size={n} attempts={attempt+1}', flush=True)
                time.sleep(.05)
    print(f'VERIFIED {args.rounds*len(lengths)} hardware UDP round trips')
    return 0

def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=PORT_DEFAULT)
    parser.add_argument("--fpga-ip", default="10.0.0.250")
    parser.add_argument("--timeout", type=float, default=30.0,
                        help="hello-wait deadline / per-attempt timeout")
    parser.add_argument("--retries", type=int, default=3)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("listen")
    sub.add_parser("hello-wait")
    verify = sub.add_parser("verify")
    verify.add_argument("--rounds", type=int, default=3)
    sender = sub.add_parser("send")
    sender.add_argument("text")
    args = parser.parse_args()
    if args.cmd == "listen":
        cmd_listen(args)
    elif args.cmd == "hello-wait":
        return cmd_hello_wait(args)
    elif args.cmd == "verify":
        return cmd_verify(args)
    elif args.cmd == "send":
        return cmd_send(args)


if __name__ == "__main__":
    raise SystemExit(main())
