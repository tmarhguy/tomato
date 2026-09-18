#!/usr/bin/env python3
"""Preview probe: writeback LEDs for apps + compiler sweep visibility."""
import struct
from collections import Counter
from virtual_tomato import Machine, build

def leds_of(raw):
    return (struct.unpack("<4802I", raw)[1] >> 16) & 0xFFFF

def main():
    build()
    m = Machine()
    try:
        def snap(cmd="tick"):
            return leds_of(m.step(cmd))

        def burst(n=20):
            return [snap() for _ in range(n)]

        def report(name, samples):
            changes = sum(1 for a, b in zip(samples, samples[1:]) if a != b)
            bits = 0
            for v in samples:
                bits |= v
            print(f"{name}: unique={len(set(samples))} changes={changes} "
                  f"bits={bits:04x} last={samples[-1]:04x} top={Counter(samples).most_common(3)}")
            return changes, bits

        print("=== writeback + compiler-sweep LED probe ===")
        report("menu", burst(12))

        # Fresh boot into Fib (index 4)
        m.step("reset")
        for _ in range(4):
            snap("key 31")
        snap("key 13"); snap("key 13")
        c_fib, b_fib = report("fib", burst(20))
        assert b_fib and c_fib > 3, f"Fib quiet ({c_fib},{b_fib:04x})"

        # Racer from reset (index 11)
        m.step("reset")
        for _ in range(11):
            snap("key 31")
        snap("key 13"); snap("key 16"); snap("key 16")
        c_racer, b_racer = report("racer", burst(25))
        assert b_racer and c_racer > 3, f"Racer quiet ({c_racer},{b_racer:04x})"

        # Compiler from reset (index 12); Enter starts GO on default field
        m.step("reset")
        for _ in range(12):
            snap("key 31")
        snap("key 13")
        before = snap()
        after_go = snap("key 13")  # GO — preview ORs sweep counters this step
        print(f"compiler_go: before={before:04x} after={after_go:04x} "
              f"popcount={bin(after_go).count('1')}")
        assert after_go != before or bin(after_go).count("1") >= 4, \
            "compiler GO must show sweep activity on LEDs"
        # Easy default problems still OR a run of counts; require some width.
        assert after_go != 0, "compiler sweep left LEDs dark"
        print("PASS: Fib/Racer move WB LEDs; compiler sweep shows on LED row")
    finally:
        m.close()

if __name__ == "__main__":
    main()
