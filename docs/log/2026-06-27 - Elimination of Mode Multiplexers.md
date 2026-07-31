## 1. The "Adder Pass-Through" Pipeline (Elimination of Mode Multiplexers)

**Initial State & Bottleneck:**

The previous ALU design utilized a parallel execution model. An incoming signal would split: one path raced through the A/B masking logic into the 74283 adder for arithmetic, while a simultaneous path raced through the LUT3 for logic operations. Both paths collided at the end of the slice into an array of eight 74257 Mode Multiplexers, which selected the final output. This parallel branching created immense PCB routing congestion, footprint bloat (requiring 8 dedicated 74257 ICs and 32 separate A-masking logic gates), and added a final 8ns propagation delay to the critical math path.

**The Solution (Pass-Through Architecture):**

I have completely overhauled the datapath from a parallel race to a highly optimized serial pipeline. The final 74257 multiplexers and the discrete A-masking logic have been entirely deleted.

Instead, the LUT3 output now feeds _directly_ into the `A` pins of the 74283 adder.

- **For Arithmetic:** The LUT3 is programmed via its opcode to act as a transparent wire, simply passing operand `A` to the adder. The B-mask provides `B` or `~B`.
    
- **For Logic:** The LUT3 computes the desired logical output (e.g., `A AND B`) and feeds it to the adder. The B-mask forces the `B` input to exactly `0`, and `cin` is held at `0`. The 74283 computes `(A AND B) + 0 + 0`, acting as a transparent exit conduit for the logic result.
    

**Pros:**

- **Massive Footprint Reduction:** Recovers significant PCB real estate by deleting 8x 74257 ICs and 32x A-mask gates.
    
- **Routing Competence:** Converts a messy, branching web of copper traces into a clean, linear pipeline.
    
- **Global Speed Gain:** While locally it adds a serial wait time (Adder waits for LUT3), it removes the MUX delay at the end of the 32-bit chain. This slightly improves the global worst-case timing by ~1.2ns on the FPGA.
    

**Cons:**

- Sacrifices purely independent parallel execution; logical operations are now inextricably tied to the arithmetic propagation path.
    

## 2. The 4-Bit Carry Bypass (Skip) Integration

**Initial State & Bottleneck:**

After discarding a full Lookahead Carry (74182) architecture due to the exponential routing nightmare it causes on a flat 2D PCB (the "central spine" problem), the ALU fell back to a pure Ripple Carry. While highly modular and easy to route, 32 bits of sequential 74283 ripple delays created an unbearable critical path of ~110 ns, strictly limiting the physical PCB to approximately 9 MHz.

**The Solution:**

I injected localized **Carry Bypass (Carry Skip)** logic directly into the fundamental 4-bit slice, leaving the 32-bit top-level schematic completely untouched.

![4-bit ALU final schematic in Digital](../../../media/logs/2026-06-27-alu-4b-final.png)

By utilizing four XOR gates to check if each bit is propagating ($P = A \oplus B$) and feeding them into a 4-input AND gate ($P_{group}$), a 2-to-1 multiplexer at the end of the slice determines the carry behavior. If $P_{group}$ is true, the incoming `cin` skips the 74283 adder entirely and flies directly to `cout`.

**Pros:**

- **Physical Speed Multiplier:** Shatters the sequential 32-bit ripple chain. On physical 74AHCT copper, worst-case signals skip across intermediate blocks via high-speed multiplexers (~7ns) instead of deep adders (~12ns). This pushes the physical PCB from ~9 MHz to **~16.5 MHz**, an 80% speed boost with virtually zero added global routing complexity.
    

**Cons / The FPGA Dichotomy:**

- **The Emulation Penalty:** Vivado timing reports confirmed a severe architectural dichotomy between discrete physics and FPGA synthesis. Modern FPGAs feature hyper-fast, hard-wired `CARRY4` silicon primitives. By injecting custom bypass multiplexers, Vivado was forced to abandon its native `CARRY4` blocks, synthesizing the bypass out of slower, generic programmable LUTs/MUXF7s.
    
- **The Result:** The "unleashed" FPGA speed (a pure 32-bit `assign sum = a + b`) could exceed 160+ MHz, but the custom Carry Bypass limits the FPGA to **146.5 MHz** (6.8 ns delay per slice).
    

**Conclusion:** The 146.5 MHz FPGA speed remains exceptionally healthy and perfectly adequate for high-speed emulation. I have willingly traded the highest-tier FPGA bragging rights to engineer a masterpiece for the physical medium: a cleanly routable, beautifully repetitive KiCad board that maximizes discrete 74-series silicon speeds.