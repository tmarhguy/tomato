; call.s — JAL/RET via pc_link; r0 stays zero (hardwired)
    ADDI    r1, r0, 0
    JAL     r0, sub          ; return here next (link in pc_link only)
    ADDI    r1, r0, 99       ; must execute after RET
    HALT
sub:
    ADDI    r2, r0, 42
    RET
