; counter.s — count r1 from 0 to 10, HALT (disp latches 10)
    ZERO    r0
    ADDI    r2, r0, 10
    ADDI    r1, r0, 0
loop:
    ADDI    r1, r1, 1
    CMP     r1, r2
    BNE     loop
    HALT
