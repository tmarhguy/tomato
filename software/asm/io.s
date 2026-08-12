; io.s — IN / OUT peripheral path (lane sel=2 + io_out latch)
    ADDI    r2, r0, 0x41       ; 'A'
    OUT     r2
    IN      r1                 ; expect kb_data from TB
    FENCE
    HALT
