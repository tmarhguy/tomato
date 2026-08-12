; fib.s — fib(8) → r1 = 21, store/load at [r5], HALT
    ZERO    r0
    ADDI    r1, r0, 0          ; a = 0
    ADDI    r2, r0, 1          ; b = 1
    ADDI    r3, r0, 8          ; n = 8
loop:
    CMP     r3, r0
    BEQ     done
    ADD     r4, r1, r2         ; t = a+b
    MOV     r1, r2             ; a = b
    MOV     r2, r4             ; b = t
    ADDI    r3, r3, -1
    JMP     loop
done:
    ADDI    r5, r0, 32
    SW      r1, r5, 0
    LW      r6, r5, 0
    HALT
