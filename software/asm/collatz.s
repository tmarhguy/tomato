; collatz.s — Collatz steps for n=27 → r2 = 111, HALT
; 3n+1 = n + n + n + 1; n/2 = LSR by 1. No MUL.
    ZERO    r0
    ADDI    r1, r0, 27         ; n
    ADDI    r2, r0, 0          ; steps
    ADDI    r5, r0, 1          ; const 1
loop:
    CMP     r1, r5
    BEQ     done               ; while n != 1
    AND     r4, r1, r5         ; n & 1
    CMP     r4, r0
    BNE     odd
    ; even: n >>= 1
    LSR     r1, r1, r5
    JMP     step
odd:
    ; n = 3n+1
    ADD     r3, r1, r1
    ADD     r3, r3, r1
    ADDI    r1, r3, 1
step:
    ADDI    r2, r2, 1
    JMP     loop
done:
    MOV     r1, r2             ; show steps on disp via last WB
    HALT
