; ecall.s — syscall trap at 0x100; RET resumes
; ABI: r1 = call# ; r2 = arg0 ; return in r1
;   0 = exit (HALT)
;   1 = put  (r1 ← r2)
;   2 = getc (r1 ← IN)
    ADDI    r1, r0, 1          ; SYS_PUT
    ADDI    r2, r0, 42
    ECALL
    ; r1 should be 42 after RET
    ADDI    r3, r0, 42
    CMP     r1, r3
    BNE     fail
    HALT
fail:
    ADDI    r1, r0, 0
    HALT

.org 0x100
trap:
    CMP     r1, r0
    BEQ     sysexit
    ADDI    r4, r0, 1
    CMP     r1, r4
    BEQ     sysput
    ADDI    r4, r0, 2
    CMP     r1, r4
    BEQ     sysgetc
    RET                      ; unknown → resume
sysexit:
    HALT
sysput:
    MOV     r1, r2
    RET
sysgetc:
    IN      r1
    RET
