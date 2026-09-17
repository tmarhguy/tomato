# Remote compute — OS/preview ABI v1

This is a simulation-only integration checkpoint. No bitstream was generated
or programmed. The Mac app and production Supabase bridge are unchanged by
this iteration. Results are emitted by actual Tomato RTL executing OS assembly;
the Python compiler does not compute answers. The preview labels results as
RTL simulation, never as physical FPGA execution.

## Run and test

`python3 tools/virtual_tomato.py` serves http://127.0.0.1:8766/.
Open Envelop with Up, Center; click Connect demo phone. A live Hi, Hey, or
Hello receives this personalized, ACK-gated firmware sequence:

1. `Hello, {firstname}! I'm Tomato.`
2. `I reply from a dorm table I call home.`
3. `Tyrone Marhguy built me transistor-up!`
4. `Try 23 + 19 on my dual-LUT ALU!`

Names are bounded so the complete introduction stays within Tomato's
40-character display record. Enter commands in the multiline simulated-phone
field. The transcript records actual outgoing firmware replies and separately
labels compiler errors.

`make -C hardware/fpga/core remote-test` runs native compute cases, randomized
ALU checks, malformed binary jobs, firmware transport and sandbox tests, plus
launcher/game/chat regression. No FPGA tools are invoked.

## Grammar currently implemented

- `/calc 23 + 19`: `+ - & | ^`, decimal, hexadecimal, binary literals.
- `/run` followed by newline- or semicolon-separated instructions.
- `R0 = 42` through `R7`; values -2147483648..4294967295, modulo-32-bit results.
- `ADD SUB AND OR XOR dst,a,b`.
- `MASKADD XORAND dst,a,b,c` use the real compound ISA instructions.
- `STORE [0..255],R0` and `LOAD R0,[0..255]`.
- Exactly one `RETURN R0`, last; maximum 32 instructions, 2048 source characters.
- `/help` and Hi/Hey/Hello are handled by OS firmware. Other ordinary text gets
  a bounded fallback. Only one ordinary outgoing chat message is in flight;
  greeting and help sequences advance only after ACKs using the existing retry
  path. Duplicate/history messages remain silent. Requests arriving while a
  chat reply is pending may not get another automatic chat reply.

Example:

```
/run
R0 = 0x20
R1 = 15
R2 = 3
MASKADD R3,R0,R1,R2
STORE [0],R3
LOAD R4,[0]
ADD R5,R4,R2
RETURN R5
```

Expected result: 38 / 0x00000026.

## Wire format for other implementers

Existing PG framing and CRC remain unchanged. New frame type **32** is a job,
using an existing nonzero contact route. Payload is tokenBE32, version byte 1,
then records below. Maximum payload 197 bytes. The firmware independently
checks the whole program before clearing or changing sandbox registers/memory.
It then walks the same records sequentially. No host machine code is accepted.

| Bytecode | Record bytes |
|---|---|
| 1 SET | op, dst, immediateBE32 (6 total) |
| 2..8 ADD/SUB/AND/OR/XOR/MASKADD/XORAND | op,dst,a,b,c (5); binary ops ignore c but validate it |
| 32 LOAD | op,dst,offset8 (3) |
| 33 STORE | op,src,offset8 (3) |
| 48 RETURN | op,src (2); must end payload |

Reply frame type **33**, same route: tokenBE32,status8,resultBE32 (9 bytes).
Status 0 is success. Errors: 1 INVALID_OPCODE, 2 PROGRAM_TOO_LONG,
3 REGISTER_RANGE, 4 MEMORY_RANGE, 5 MISSING_RETURN, 6 UNSUPPORTED_RAW_LUT,
7 MALFORMED_PROGRAM. Result is zero on error. A job without a complete token
is dropped. Unknown/unverified routes are ignored. Error text and hexadecimal
results are projected into the actual OS chat framebuffer.

This checkpoint sends one result frame, without durable result retry/cache,
accepted/running frames or production job-state updates. A repeated job is
deterministically re-executed from cleared state. Before production integration,
add token-correlated result ACK/retry and a bounded result cache. Preserve a
pending normal-chat TX projection until its ACK; compute still returns its
binary result while that chat is pending.

## Reserved RAM and ABI

| Region | Purpose |
|---|---|
| 0x1500 onward, below 0x1600 | Chat help/fallback code |
| 0x1600..0x17ff | Greeting/help/error strings and sequence lookup tables |
| 0x1d00 onward, below 0x2000 | Executor code |
| 0x26a0..0x26bf | Executor state, result packet and saved OS r10 |
| 0x26c0 onward | Result label |
| 0x26e0..0x26e7 | Eight virtual registers |
| 0x2700..0x27ff | 256 private 32-bit words |

Strict assembly checks emitted code AND `.space` allocations for overlap and
16K-word overflow. Existing desktop strings occupy 0x3000 onward: that region
is not free. Execution preserves the OS framebuffer base, keyboard/timer base,
text-width register, parser/service return links, menu register and BLE bases.
Host-visible R0 is virtual storage; it is not physical zero register r0.

## Explicit next steps

1. Implement/freeze LUTCFG/LUTEXEC ISA, assembler, RTL and randomized equivalence
   tests. Current compiler and executor reject raw operations explicitly.
2. Define virtual flags independently of interpreter CMP/loop housekeeping;
   otherwise H=Z/C/etc would read the interpreter's flags rather than job flags.
   Native arithmetic is working; remote flag-derived H semantics are not claimed.
3. Add raw bytecode execution only after those interfaces are verified.
4. Integrate a shared strict compiler, durable FIFO job model, rate limits,
   result ACK/retry, and contact/job sync into the production backend and bridge.
5. Add job/result UI to native clients; preserve chat compatibility. Full register
   trace, offline queued jobs, real BLE compute and raw ALU tests remain pending.
6. Only then request hardware deployment; current user instruction forbids it.

## Envelop local integration (2026-09-15)

Start `python3 tools/virtual_tomato.py`. Envelop/apple’s packaged app offers
**Use Tomato** in the device conversation (and **Try Tomato locally** before
profile restoration). It calls `/interpret` for original/canonical/bytecode,
tries its current eligible BLE route, then offers explicit virtual fallback.
`/execute` starts an isolated CPU RTL instance with the same OS and compiler.
This is a local development service, bound to loopback with host validation and
per-process request token; it is not a public authenticated cloud executor.

`python3 tools/test_remote_service.py` tests the running service. Natural example:
`What is (57 + 19) AND 0x3F?` → native ADD then AND → `12 / 0x0000000C`.
See the root sprint in both repositories for the remaining lifecycle and cloud
work. Current physical firmware was deliberately not upgraded in this sprint.
