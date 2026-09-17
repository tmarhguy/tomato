#!/usr/bin/env python3
"""Focused Envelop tests: run the shipped firmware on the actual Tomato RTL."""
import binascii
import subprocess
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "software"))
import assembler
CORE = ROOT / "hardware/fpga/core"
def frame(t, route=0, payload=b""):
    b = bytes([80,71,1,t])+route.to_bytes(2,"big")+len(payload).to_bytes(2,"big")+payload
    return b+binascii.crc_hqx(b,0xffff).to_bytes(2,"big")
def main():
    subprocess.run(["make","tb/mem/tomato_os.mem"],cwd=CORE,check=True)
    labels={}
    image=assembler.assemble((CORE/"sim/tomato_os_all.s").read_text(),assembler.load_opcodes(),
                             symbols=labels, strict_layout=True, max_words=16384)
    assert len(image)<=16384
    # Bound every new code/data island before adjacent existing OS regions.
    assert labels["en_event_fault"] < 0x1800
    assert labels["en_putn_ret"] < 0x2600
    assert labels["trib_result"] < 0x2800
    assert labels["en_greet_ret"] < 0x2000
    assert labels["remote_e7"] < 0x1800
    assert labels["en_s_limit"] + 80 < 0x3f00
    fixed_greeting = [
      "I reply from a dorm table I call home.",
      "Tyrone Marhguy built me transistor-up!",
      "Try 23 + 19 on my dual-LUT ALU!",
    ]
    assert all(len(line) <= 40 for line in fixed_greeting)
    out=[f"localparam {k.upper()} = 24'h{v:06x};" for k,v in labels.items()
         if k.startswith(("en_", "remote_", "trib_")) or k in ("game_over", "go_key", "s_tt_over")]
    halt = assembler.assemble('HALT', assembler.load_opcodes())[0]
    out.append(f"localparam HALT_WORD = 32'h{halt:08x};")
    vectors={
      "invalid_compute":frame(32,7,b"\0\0\0\1\1"+bytes([1,0,0,0,0,1,33,0,0,48,8])),
      "hello":frame(1),
      "hello_ack":frame(2,payload=b"ENVELOP/1\nDEVICE=TOMATO\nID=TOMATO-001"),
      "reset_contacts":frame(3),
      "contact":frame(4,7,b"\x01\x01Ama Mensah"),
      "bad_contact":frame(4,8,b"\x01\x01Bad\nName"),
      "message":frame(7,7,b"\x00\x00\x00\x2aHello"),
      "ack":frame(9,7,b"\x00\x00\x00\x2a"),
      "auto_reply":frame(8,7,b"\x00\x00\x00\x01Hello, Ama! I'm Tomato."),
      "server_ack":frame(9,7,b"\x00\x00\x00\x01"),
      "personality_1":frame(8,7,b"\x00\x00\x00\x02I reply from a dorm table I call home."),
      "server_ack_2":frame(9,7,b"\x00\x00\x00\x02"),
      "personality_2":frame(8,7,b"\x00\x00\x00\x03Tyrone Marhguy built me transistor-up!"),
      "server_ack_3":frame(9,7,b"\x00\x00\x00\x03"),
      "personality_3":frame(8,7,b"\x00\x00\x00\x04Try 23 + 19 on my dual-LUT ALU!"),
      "server_ack_4":frame(9,7,b"\x00\x00\x00\x04"),
      "wrong_ack":frame(9,8,b"\x00\x00\x00\x01"),
      "ping":frame(11,payload=b"\x00\xff"),
      "pong":frame(12,payload=b"\x00\xff"),
      "long_message":frame(7,7,b"\x00\x00\x00\x2b"+b"x"*256),
      "bad_text":frame(7,7,b"\x00\x00\x00\x2cfoo\x00bar"),
      "history":frame(6,7,b"\x00\x00\x00\x30\x00Hi"),
      "unknown_route":frame(7,99,b"\x00\x00\x00\x31Hi"),
      "manual":frame(8,7,b"\x00\x00\x00\x05ok"),
    }
    for name,b in vectors.items():
        out += [f"task load_{name}; begin",f"n = {len(b)};"]
        out += [f"packet[{i}] = 8'h{v:02x};" for i,v in enumerate(b)]
        out += ["end endtask"]
    (CORE/"sim/envelop_vectors.vh").write_text("\n".join(out)+"\n")
    rtl=[str(p.relative_to(CORE)) for p in (CORE/"rtl").glob("*.v")]
    subprocess.run(["iverilog","-g2012","-DTOMATO_SIM","-Irtl","-Isim","-s","envelop_tb","-o","sim/envelop_tb.vvp",*rtl,"tb/envelop_tb.v"],cwd=CORE,check=True)
    subprocess.run(["vvp","sim/envelop_tb.vvp"],cwd=CORE,check=True)
if __name__=="__main__": main()
