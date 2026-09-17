# Ethernet send/receive bring-up — Nexys A7-100T

A small independent design: LAN8720A RMII receive + transmit, Clause22 MDIO
polling, static-IP ARP/UDP echo endpoint, 640×480 HDMI through the existing
JC/JD DVI PMOD, and 115200 8N1 USB UART. No Tomato CPU synthesis, Internet
claims, DHCP/TCP/TLS or IP stack beyond an ARP responder and UDP echo.
The existing OS/Envelop bitstream remains in core/build/envelop-compute.

Board config (override in `rtl/ethernet_top.v`, rebuild if your router differs):
FPGA MAC `02:54:4F:4D:41:54`, FPGA IP `10.0.0.250`, UDP port `5000`.
The laptop must be on the same /24. The FPGA answers ARP for its IP, echoes
any UDP datagram sent to port 5000 back to the sender (up to 512 payload
bytes), and broadcasts `TOMATO HELLO <ctr> IP=<hex>` to `255.255.255.255:5000`
every ~5s while idle for discovery. `lan_min.v` retains its simulation default
192.168.1.10; the board top overrides it to the observed home LAN.
10.0.0.250 had no ARP response before this test; reserve it in the router
before permanent use to avoid a future DHCP collision. One outstanding TX; arrivals while busy are dropped
and counted (UDP senders retry).

## Run

```sh
cd hardware/fpga/ethernet_test
make test
python3 tools/test_ethernet_pipeline.py
make -j8 fpga CHIPDB=../core/build/chipdb/chipdb.bin
make program CHIPDB=../core/build/chipdb/chipdb.bin
```

Programming replaces the running SRAM design until reloaded/power-cycled.
Rollback from core/: `make program BUILD=build/envelop-compute CHIPDB=build/chipdb/chipdb.bin`.

## Talk to it (least friction)

From this directory, with the board programmed and the cable connected:

```sh
python3 tools/tomato_lan.py hello-wait     # wait for broadcast HELLO, learn FPGA IP
python3 tools/tomato_lan.py listen         # watch HELLOs + all port-5000 traffic
python3 tools/tomato_lan.py --timeout 2 send "hello tomato"   # send, wait for echo, verify match
python3 tools/tomato_lan.py --timeout 2 verify --rounds 3
```

`verify` checks 27 fresh binary round trips, sizes 0–512 bytes.
`send` retries 3× and exits nonzero on mismatch/timeout. Payloads are raw
bytes (1–512); framing above UDP (chat/compute protocol) is the next layer,
not this test. If your LAN is not `10.0.0.x`, edit the `FPGA_IP` override in
`rtl/ethernet_top.v`, rebuild, and pass `--fpga-ip`.

## What the HDMI screen means

- PHY ID: expected 0007C0Fx (revision low bits vary).
- LINK: UP means the PHY reports a negotiated cable link, not Internet access.
- 100M MODE: YES is required by this first receiver. 10Mbps RX is not implemented.
- VALID RX / BAD RX: Ethernet frames passing/failing the receive checks.
- TX FRAMES: completed ARP replies, UDP replies and discovery HELLO frames.
- UDP RX: datagrams accepted after header, length and checksum validation.
- ARP REPLIES / BUSY DROPS: address resolution and overload diagnostics.
- UDP RECEIVED / REPLY SENT: receive/transmit counters have both advanced.
  The laptop's matching-payload test is the end-to-end delivery proof.

Numbers are hexadecimal. There may be a wait for router broadcast/multicast
traffic: the switch does not forward arbitrary other devices' unicast traffic
to this port. A valid packet proves reception only, not DHCP or Internet routing.

USB UART on the board's second FTDI channel prints two alternating lines
once/second each. Line 1 is the original status; line 2 is the echo path:

```text
TOMATO ETH PHY=0007:C0F1 LINK=1 100M=1 GOOD=... BAD=... ACT=... TYPE=... LEN=...
TOMATO ECHO TX=00000002 RXUDP=00000005 ARP=00000001 DROP=00000000 SRC=C0A80114
```

`TX` counts transmitted frames (ARP replies + UDP echoes + HELLOs), `RXUDP`
accepted UDP datagrams, `ARP` ARP replies sent, `DROP` frames dropped while
the single TX slot was busy, `SRC` the last UDP sender IP in hex.
Use `python3 tools/ethernet_serial.py` from this directory. LEDs0 heartbeat,1 PHY
present,2 link,3 any valid traffic either direction.
The CPU reset button restarts PHY reset and clears counters.

## Design and limits

100MHz oscillator → 50MHz RMII reference and 25MHz video. PHY held in reset
for ~84ms with its reference clock running. RMII receiver + transmitter;
no MII/RMII converter. PHY address1. MDC1MHz. MDIO reads ID1/ID2/BMSR/special
status; BMSR is polled repeatedly to handle latch-low link status.
Only unicast UDP to this MAC/IP/port is echoed. IPv4 options/fragments,
bad IP checksums, invalid nonzero UDP checksums and inconsistent/truncated
lengths are rejected. UDP checksum zero is accepted for IPv4.
TX builds preamble/SFD, auto-pads to 60 bytes, appends IEEE FCS and 96-bit
IFG; IP checksum recomputed per packet, UDP checksum zero (legal IPv4).
Frame-tail CRS_DV alternation is handled; frame byte reconstruction and reflected
CRC are tested with independent Python-zlib-generated FCS. Display snapshots
cross via a request/acknowledge handshake; UART snapshots stay in the RX domain.
Header checksum calculation is pipelined over three clocks. The build targets
50MHz for the internal network domain (pixel logic runs at 25MHz). The board
oscillator remains 100MHz. Internal timing passes are not a board-level RMII
timing closure proof.

Tests: valid ARP-type frame, CRC corruption, PHY RXERR, alternating CRS_DV tail,
disabled receiver; MDIO read headers, address, turnaround and response bits;
TX preamble/SFD, streaming, pad-to-60, FCS residue, IFG, busy gate;
ARP reply bytes, UDP echo 9/100B with IP-checksum verification, wrong-port
and bad-CRC silence, auto-HELLO broadcast (`make test` runs all four sims).

## Next gates

1. Board proof: HELLO seen by `tomato_lan.py hello-wait`, `send` echo OK,
   UART `TX/RXUDP` counting, zero `DROP`/`BAD` on chat-rate traffic.
2. Envelop-over-UDP framing inside the echo payload (reuse the existing
   Envelop binary frames, not a new protocol), then an explicitly labeled local adapter that
   bridges UDP to the Envelop backend. Direct Internet routing follows separately.
3. Integrate a small packet FIFO/MMIO into Tomato, with OS network status.
4. Decide endpoint authentication/TLS architecture and memory budget before
   Internet deployment; never call raw UDP or an unauthenticated bridge secure.
   For Internet reach the FPGA must send to the gateway MAC with the server
   IP (one-entry ARP cache); Tomato initiates with HELLO so NAT opens.
5. Test replay/duplicate handling, packet bounds, malformed traffic, disconnect,
   credential storage and recovery before Envelop transport migration.

## Primary references

- https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf (§4)
- https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Nexys-A7-100T-Master.xdc
- https://ww1.microchip.com/downloads/en/DeviceDoc/00002165B.pdf (RMII, Clause22, registers)

## Independent fast test

`python3 tools/test_ethernet_pipeline.py` creates packets using Python struct,
one's-complement checksums and independent zlib FCS verification, drives the
actual `lan_min`/`rmii_tx` Verilog through Icarus, then decodes transmitted bytes.
19 cases cover empty/odd/even/maximum payloads and malformed traffic. This is
RTL simulation, not a Python reimplementation pretending to be the FPGA.
Build/program only after these tests pass. Runtime is under one second here.
