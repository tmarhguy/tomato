; bytes.s — SB/LB byte0 lane round-trip (r0 hardwired 0)
    ADDI    r5, r0, 40       ; base addr
    ADDI    r3, r0, 0x5A
    SW      r0, r5, 0        ; clear word
    SB      r3, r5, 0        ; store byte0
    LB      r1, r5, 0        ; sext → 0x5A
    ADDI    r3, r0, 0x80
    SB      r3, r5, 0
    LB      r2, r5, 0        ; sext → 0xFFFFFF80
    HALT
