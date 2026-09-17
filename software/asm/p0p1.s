; p0p1.s — P0/P1 integration vectors (deterministic, self-checking)
; PASS: r1=1. FAIL: r1=0. Uses only burned ops + new P0/P1.
    ZERO    r0
    ADDI    r10, r0, 60        ; a
    ADDI    r11, r0, 15        ; b
    ADDI    r12, r0, 7         ; c
    ADDI    r15, r0, 255       ; low-byte mask
; ANDN: 60 & ~15 = 48
    ANDN    r13, r10, r11
    ADDI    r14, r0, 48
    CMP     r13, r14
    BNE     fail
; ORN low byte: (60 | ~15) & 0xFF = 252
    ORN     r13, r10, r11
    AND     r13, r13, r15
    ADDI    r14, r0, 252
    CMP     r13, r14
    BNE     fail
; CSEL: c=7 -> per-bit mux = 12
    CSEL    r13, r10, r11, r12
    ADDI    r14, r0, 12
    CMP     r13, r14
    BNE     fail
; ANDADD: (60&15)+7 = 19
    ANDADD  r13, r10, r11, r12
    ADDI    r14, r0, 19
    CMP     r13, r14
    BNE     fail
; ORADD: (60|15)+7 = 70
    ORADD   r13, r10, r11, r12
    ADDI    r14, r0, 70
    CMP     r13, r14
    BNE     fail
; XORADD: (60^15)+7 = 58
    XORADD  r13, r10, r11, r12
    ADDI    r14, r0, 58
    CMP     r13, r14
    BNE     fail
; ADC with C=0: clear carry via 0+0, then 60+15+0=75
    ADD     r13, r0, r0
    ADC     r13, r10, r11
    ADDI    r14, r0, 75
    CMP     r13, r14
    BNE     fail
; SBC with C=1: CMP r0,r0 sets C, then 60-15=45
    CMP     r0, r0
    SBC     r13, r10, r11
    ADDI    r14, r0, 45
    CMP     r13, r14
    BNE     fail
; RSB: 15-60 = -45
    RSB     r13, r10, r11
    ADDI    r14, r0, -45
    CMP     r13, r14
    BNE     fail
    ADDI    r1, r0, 1
    HALT
fail:
    ADDI    r1, r0, 0
    HALT
