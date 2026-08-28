# Tomato FPGA CPI (Icarus `prog_tb`)

Sim-only: cycle + fetch-retire from reset release to halt. Not a board MHz claim.

| Program | Cycles | Instr retired | CPI |
|---------|--------|---------------|-----|
| counter | 68 | 34 | **2.000** |
| fib | 134 | 66 | **2.030** |
| collatz | 2096 | 1048 | **2.000** |
| call | 12 | 6 | **2.000** |
| bytes | 23 | 9 | **2.556** |
| softops | 20 | 9 | **2.222** |

Reproduce: `make -C hardware/fpga/core cpi`
