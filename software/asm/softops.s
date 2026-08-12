; softops.s — compose ROL via ROR(32-n); LBU zext; no new silicon
    ADDI    r1, r0, 0x81       ; 0x00000081
    ADDI    r2, r0, 1
    ROR     r3, r1, r2         ; ror 1
    ADDI    r2, r0, 31
    ROR     r4, r1, r2         ; ≡ rol 1 → 0x102
    ADDI    r5, r0, 64
    SB      r1, r5, 0
    LBU     r6, r5, 0          ; 0x81 unsigned
    HALT
