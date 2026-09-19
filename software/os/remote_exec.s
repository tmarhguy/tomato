; Preview compute ABI v1: type32, route of known contact, payload tokenBE32,
; version=1, bytecode. Reply type33: tokenBE32,status,resultBE32.
; No arbitrary instruction injection. Two passes validate before execution.
.org 0x1d00
remote_exec:
    ZERO r27
    LUI r27,2
    ADDI r27,r27,0x6a0
    SW r10,r27,17
    ADDI r11,r0,4
    CMP r23,r11
    BLT remote_no_token
    SW r0,r27,0
    SW r0,r27,4
    SW r0,r27,5
    ADDI r11,r0,7
    CMP r23,r11
    BLT remote_bad_format
    ADDI r11,r0,197
    CMP r11,r23
    BLT remote_too_long
    LW r11,r30,12
    ADDI r12,r0,1
    CMP r11,r12
    BNE remote_bad_format
    ADDI r24,r30,13
    ADD r23,r30,r23
    ADDI r23,r23,8
    SW r24,r27,1
    SW r23,r27,2
    ZERO r26
    LUI r26,2
    ADDI r26,r26,0x6e0
remote_pass:
    ZERO r21
remote_next:
    CMP r24,r23
    BGE remote_missing_return
    ADDI r21,r21,1
    ADDI r11,r0,32
    CMP r11,r21
    BLT remote_too_long
    LW r18,r24,0
    ADDI r11,r0,1
    CMP r18,r11
    BEQ remote_set
    ADDI r11,r0,16
    CMP r18,r11
    BEQ remote_raw_unsupported
    ADDI r11,r0,17
    CMP r18,r11
    BEQ remote_raw_unsupported
    ADDI r11,r0,32
    CMP r18,r11
    BEQ remote_memory
    ADDI r11,r0,33
    CMP r18,r11
    BEQ remote_memory
    ADDI r11,r0,48
    CMP r18,r11
    BEQ remote_return
    ADDI r11,r0,2
    CMP r18,r11
    BLT remote_invalid_opcode
    ADDI r11,r0,14
    CMP r18,r11
    BGE remote_invalid_opcode
    ADDI r11,r24,5
    CMP r23,r11
    BLT remote_bad_format
    LW r10,r24,1
    LW r12,r24,2
    LW r13,r24,3
    LW r14,r24,4
    OR r15,r10,r12
    OR r15,r15,r13
    OR r15,r15,r14
    ADDI r11,r0,8
    CMP r15,r11
    BGE remote_register_range
    ADDI r24,r24,5
    LW r11,r27,0
    CMP r11,r0
    BEQ remote_next
    ADD r10,r26,r10
    ADD r12,r26,r12
    ADD r13,r26,r13
    ADD r14,r26,r14
    LW r12,r12,0
    LW r13,r13,0
    LW r14,r14,0
    ADDI r11,r0,2
    CMP r18,r11
    BEQ remote_add
    ADDI r11,r0,3
    CMP r18,r11
    BEQ remote_sub
    ADDI r11,r0,4
    CMP r18,r11
    BEQ remote_and
    ADDI r11,r0,5
    CMP r18,r11
    BEQ remote_or
    ADDI r11,r0,6
    CMP r18,r11
    BEQ remote_xor
    ADDI r11,r0,7
    CMP r18,r11
    BEQ remote_maskadd
    ADDI r11,r0,8
    CMP r18,r11
    BEQ remote_xorand
    ADDI r11,r0,9
    CMP r18,r11
    BEQ remote_andadd
    ADDI r11,r0,10
    CMP r18,r11
    BEQ remote_oradd
    ADDI r11,r0,11
    CMP r18,r11
    BEQ remote_xoradd
    ADDI r11,r0,12
    CMP r18,r11
    BEQ remote_andn
    ADDI r11,r0,13
    CMP r18,r11
    BEQ remote_orn
    JMP remote_invalid_opcode
remote_add:
    ADD r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_sub:
    SUB r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_and:
    AND r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_or:
    OR r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_xor:
    XOR r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_maskadd:
    MASKADD r15,r12,r13,r14
    SW r15,r10,0
    JMP remote_next
remote_xorand:
    XORAND r15,r12,r13,r14
    SW r15,r10,0
    JMP remote_next
remote_andadd:
    ANDADD r15,r12,r13,r14
    SW r15,r10,0
    JMP remote_next
remote_oradd:
    ORADD r15,r12,r13,r14
    SW r15,r10,0
    JMP remote_next
remote_xoradd:
    XORADD r15,r12,r13,r14
    SW r15,r10,0
    JMP remote_next
remote_andn:
    ANDN r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_orn:
    ORN r15,r12,r13
    SW r15,r10,0
    JMP remote_next
remote_set:
    ADDI r11,r24,6
    CMP r23,r11
    BLT remote_bad_format
    LW r10,r24,1
    ADDI r11,r0,8
    CMP r10,r11
    BGE remote_register_range
    LW r11,r27,0
    CMP r11,r0
    BEQ remote_set_skip
    ADD r10,r10,r26
    ZERO r12
    ADDI r13,r24,2
    ADDI r14,r0,4
    ADDI r15,r0,8
remote_literal:
    LSL r12,r12,r15
    LW r11,r13,0
    OR r12,r12,r11
    ADDI r13,r13,1
    ADDI r14,r14,-1
    CMP r14,r0
    BNE remote_literal
    SW r12,r10,0
remote_set_skip:
    ADDI r24,r24,6
    JMP remote_next
remote_memory:
    ADDI r11,r24,3
    CMP r23,r11
    BLT remote_bad_format
    LW r10,r24,1
    ADDI r11,r0,8
    CMP r10,r11
    BGE remote_register_range
    LW r12,r24,2
    ADDI r11,r0,256
    CMP r12,r11
    BGE remote_memory_range
    ADDI r24,r24,3
    LW r11,r27,0
    CMP r11,r0
    BEQ remote_next
    ADD r10,r10,r26
    ZERO r13
    LUI r13,2
    ADDI r13,r13,0x700
    ADD r13,r13,r12
    ADDI r11,r0,32
    CMP r18,r11
    BEQ remote_load
    LW r12,r10,0
    SW r12,r13,0
    JMP remote_next
remote_load:
    LW r12,r13,0
    SW r12,r10,0
    JMP remote_next
remote_return:
    ADDI r11,r24,2
    CMP r23,r11
    BNE remote_bad_format
    LW r10,r24,1
    ADDI r11,r0,8
    CMP r10,r11
    BGE remote_register_range
    LW r11,r27,0
    CMP r11,r0
    BNE remote_success
    ADDI r11,r0,1
    SW r11,r27,0
    ZERO r12
    LUI r12,2
    ADDI r12,r12,0x700
    ADDI r13,r0,256
remote_clear:
    SW r0,r12,0
    ADDI r12,r12,1
    ADDI r13,r13,-1
    CMP r13,r0
    BNE remote_clear
    SW r0,r26,0
    SW r0,r26,1
    SW r0,r26,2
    SW r0,r26,3
    SW r0,r26,4
    SW r0,r26,5
    SW r0,r26,6
    SW r0,r26,7
    LW r24,r27,1
    JMP remote_pass
remote_success:
    ADD r10,r10,r26
    LW r12,r10,0
    SW r12,r27,5
    JMP remote_reply
remote_invalid_opcode:
    ADDI r11,r0,1
    SW r11,r27,4
    JMP remote_reply
remote_too_long:
    ADDI r11,r0,2
    SW r11,r27,4
    JMP remote_reply
remote_register_range:
    ADDI r11,r0,3
    SW r11,r27,4
    JMP remote_reply
remote_memory_range:
    ADDI r11,r0,4
    SW r11,r27,4
    JMP remote_reply
remote_missing_return:
    ADDI r11,r0,5
    SW r11,r27,4
    JMP remote_reply
remote_raw_unsupported:
    ADDI r11,r0,6
    SW r11,r27,4
    JMP remote_reply
remote_bad_format:
    ADDI r11,r0,7
    SW r11,r27,4
    JMP remote_reply
remote_reply:
    ; Display a received compute job without transmitting/parsing source text.
    ADDI r10,r25,40
    ZERO r12
    LUI r12,1
    ADDI r12,r12,0x720
remote_job_label:
    LW r11,r12,0
    SW r11,r10,0
    CMP r11,r0
    BEQ remote_job_labeled
    ADDI r12,r12,1
    ADDI r10,r10,1
    JMP remote_job_label
remote_job_labeled:
    ; Compact result on the actual VGA chat. Preserve any pending chat send.
    LW r11,r28,16
    CMP r11,r0
    BNE remote_wire
    ADDI r10,r25,84
    ZERO r12
    LUI r12,2
    ADDI r12,r12,0x6c0
    LW r11,r27,4
    CMP r11,r0
    BEQ remote_label
    ZERO r12
    LUI r12,1
    ADDI r12,r12,0x710
    ADD r12,r12,r11
    LW r12,r12,0
remote_label:
    LW r13,r12,0
    CMP r13,r0
    BEQ remote_hex_start
    SW r13,r10,0
    ADDI r12,r12,1
    ADDI r10,r10,1
    JMP remote_label
remote_hex_start:
    LW r12,r27,5
    LW r11,r27,4
    CMP r11,r0
    BEQ remote_hex_value
    JMP remote_finish_text
remote_hex_value:
    ADDI r14,r0,28
    ADDI r15,r0,15
remote_hex_loop:
    LSR r13,r12,r14
    AND r13,r13,r15
    ADDI r11,r0,10
    CMP r13,r11
    BLT remote_hex_digit
    ADDI r13,r13,7
remote_hex_digit:
    ADDI r13,r13,48
    SW r13,r10,0
    ADDI r10,r10,1
    ADDI r14,r14,-4
    CMP r14,r0
    BGE remote_hex_loop
remote_finish_text:
    SW r0,r10,0
    ADDI r11,r25,84
    SUB r10,r10,r11
    SW r10,r25,3
remote_wire:
    ADDI r11,r0,1
    SW r11,r28,7
    ADDI r4,r27,8
    LW r11,r30,8
    SW r11,r4,0
    LW r11,r30,9
    SW r11,r4,1
    LW r11,r30,10
    SW r11,r4,2
    LW r11,r30,11
    SW r11,r4,3
    LW r11,r27,4
    SW r11,r4,4
    LW r12,r27,5
    ADDI r13,r0,24
    ADDI r14,r0,255
    ADDI r15,r4,5
remote_result_bytes:
    LSR r11,r12,r13
    AND r11,r11,r14
    SW r11,r15,0
    ADDI r15,r15,1
    ADDI r13,r13,-8
    CMP r13,r0
    BGE remote_result_bytes
    ADDI r1,r0,33
    LW r10,r27,17
    MOV r2,r22
    ADDI r3,r0,9
    JAL r16,en_queue
    JR r19
remote_no_token:
    LW r10,r27,17
    JR r19
.org 0x26a0
remote_state: .space 32
.org 0x26c0
remote_result_label: .asciz "Result: 0x"
remote_error_label: .asciz "ERR: 0x"
.org 0x26e0
remote_registers: .space 8
.org 0x2700
remote_memory_words: .space 256

; Chat replies are sent after the preceding ACK, using normal retry tokens.
.org 0x1500
remote_chat:
    SW r16,r28,46
    LW r11,r28,16
    CMP r11,r0
    BNE remote_chat_ret
    ADDI r11,r0,5
    CMP r27,r11
    BNE remote_chat_greet
    LW r11,r30,12
    ADDI r12,r0,47
    CMP r11,r12
    BNE remote_chat_greet
    LW r11,r30,13
    ADDI r12,r0,104
    CMP r11,r12
    BNE remote_chat_greet
    LW r11,r30,14
    ADDI r12,r0,101
    CMP r11,r12
    BNE remote_chat_greet
    LW r11,r30,15
    ADDI r12,r0,108
    CMP r11,r12
    BNE remote_chat_greet
    LW r11,r30,16
    ADDI r12,r0,112
    CMP r11,r12
    BNE remote_chat_greet
    ADDI r11,r0,2
    SW r11,r28,44
    SW r22,r28,45
    JMP remote_chat_ret
remote_chat_greet:
    JAL r16,en_greet
    LW r11,r28,16
    CMP r11,r0
    BNE remote_chat_ret
    ADDI r11,r0,3
    SW r11,r28,44
    SW r22,r28,45
remote_chat_ret:
    LW r16,r28,46
    JR r16
remote_followup:
    SW r16,r28,46
    LW r11,r28,44
    CMP r11,r0
    BEQ remote_chat_ret
    LW r1,r28,45
    JAL r16,en_find
    CMP r4,r0
    BEQ remote_chat_ret
    LW r11,r28,44
    ADDI r11,r11,-1
    ADDI r13,r0,1
    LSL r11,r11,r13
    ZERO r12
    LUI r12,1
    ADDI r12,r12,0x700
    ADD r12,r12,r11
    LW r11,r12,1
    SW r11,r28,44
    LW r12,r12,0
remote_help_copy_start:
    ADDI r13,r4,84
    ZERO r14
remote_help_copy:
    LW r11,r12,0
    SW r11,r13,0
    CMP r11,r0
    BEQ remote_help_send
    ADDI r14,r14,1
    ADDI r12,r12,1
    ADDI r13,r13,1
    JMP remote_help_copy
remote_help_send:
    SW r14,r4,3
    LW r11,r28,18
    CMP r11,r0
    BEQ remote_chat_ret
    SW r11,r28,16
    ADDI r11,r11,1
    SW r11,r28,18
    LW r11,r4,0
    SW r11,r28,17
    ADDI r11,r0,1
    SW r11,r28,7
    JAL r16,en_outgoing
    JMP remote_chat_ret
.org 0x1600
remote_help1: .asciz "/calc 23 + 19; /help for quick tips"
remote_help2: .asciz "/run: R0=42; RETURN R0. 32 ops max."
remote_fallback: .asciz "Try /help. I run bounded integer jobs."
remote_personality1: .asciz "I reply from a dorm table I call home."
remote_personality2: .asciz "Tyrone Marhguy built me transistor-up!"
remote_personality3: .asciz "Try 23 + 19 on my dual-LUT ALU!"
.org 0x1700
; State-indexed (message pointer,next state): help, fallback, then greeting.
.word remote_help2,0
.word remote_help1,1
.word remote_fallback,0
.word remote_personality3,0
.word remote_personality2,4
.word remote_personality1,5
.org 0x1710
.word 0,remote_e1,remote_e2,remote_e3,remote_e4,remote_e5,remote_e6,remote_e7
.org 0x1720
remote_job_text: .asciz "/run: bounded 32-bit job"
.org 0x1740
remote_e1: .asciz "ERR INVALID_OPCODE"
remote_e2: .asciz "ERR PROGRAM_TOO_LONG"
remote_e3: .asciz "ERR REGISTER_RANGE"
remote_e4: .asciz "ERR MEMORY_RANGE"
remote_e5: .asciz "ERR MISSING_RETURN"
remote_e6: .asciz "ERR UNSUPPORTED_RAW_LUT"
remote_e7: .asciz "ERR MALFORMED_PROGRAM"
