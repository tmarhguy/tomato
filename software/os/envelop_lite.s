; Envelop Lite. CPU firmware; no protocol/contact logic synthesized into RTL.
; See sprint.md for ABI, memory budget, tests and actual hardware status.
; r28 state, r29 ACI MMIO, r30 RX stream, r31 TX frame. r20 menu preserved.
; Links: service r7 -> event r6; parser r17 -> dispatch r19 -> leaves r16.
; State offsets: 0 ACI phase,1 setup index,2 credits,3 total credits,4 BLE
; (0 down,1 connected,2 subscribed),5 verified,6 cloud status,7 redraw,
; 8 selected,9 editing,10 character,11 draft length,12 TX length,13 TX cursor,
; 14 RX used,15 contacts,16 pending token,17 pending route,18 next token,
; 19 retry ms,20 last chunk ms,21 event cursor,22 event length,
; 23 dedup count,24 dedup cursor,25 current contact pointer,26 error.
; Contact stride128: route0,unread1, RXlen2,TXlen3, name4..36,
; RX40..80,TX84..124. Display keeps 40 chars; wire accepts 256.
.org 0x1300
en_service:
    MOV r7,r16
    LW r11,r29,0
    ADDI r12,r0,16
    AND r12,r11,r12
    CMP r12,r0
    BNE en_radio_fault
    ADDI r12,r0,2
    AND r12,r11,r12
    CMP r12,r0
    BNE en_service_ret
    ADDI r12,r0,1
    AND r12,r11,r12
    CMP r12,r0
    BEQ en_schedule
    ADDI r12,r0,2
    SW r12,r29,0
    LW r12,r29,2
    CMP r12,r0
    BEQ en_schedule
    SW r12,r28,22
    JAL r16,en_event
en_schedule:
    LW r11,r29,0
    ADDI r12,r0,4
    AND r12,r11,r12
    CMP r12,r0
    BEQ en_poll
    LW r11,r28,0
    ADDI r12,r0,1
    CMP r11,r12
    BEQ en_setup_send
    ADDI r12,r0,3
    CMP r11,r12
    BEQ en_name_send
    ADDI r12,r0,5
    CMP r11,r12
    BEQ en_adv_send
    LW r11,r28,4
    ADDI r12,r0,2
    CMP r11,r12
    BNE en_service_ret
    LW r11,r28,2
    CMP r11,r0
    BEQ en_service_ret
    LW r12,r28,12
    CMP r12,r0
    BEQ en_service_ret
    LW r13,r9,2
    LW r14,r28,20
    SUB r14,r13,r14
    ADDI r15,r0,35
    CMP r14,r15
    BLT en_service_ret
    SW r13,r28,20
    ADDI r11,r11,-1
    SW r11,r28,2
    LW r13,r28,13
    SUB r12,r12,r13
    ADDI r14,r0,20
    CMP r12,r14
    BLT en_chunk_len
    MOV r12,r14
en_chunk_len:
    ADDI r11,r0,0x15
    SW r11,r29,32
    ADDI r11,r0,3
    SW r11,r29,33
    ADD r14,r31,r13
    ADD r13,r13,r12
    SW r13,r28,13
    ADDI r15,r29,34
    ADDI r1,r12,2
    SW r1,r29,1
en_chunk_copy:
    LW r11,r14,0
    SW r11,r15,0
    ADDI r14,r14,1
    ADDI r15,r15,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_chunk_copy
    LW r12,r28,12
    CMP r13,r12
    BNE en_start
    SW r0,r28,12
    SW r0,r28,13
    JMP en_start
en_poll:
    SW r0,r29,1
en_start:
    ADDI r11,r0,1
    SW r11,r29,0
en_service_ret:
    JR r7
en_radio_fault:
    ADDI r11,r0,1
    SW r11,r28,26
    SW r11,r28,7
    SW r0,r28,4
    SW r0,r28,5
    JR r7
en_setup_send:
    LUI r14,3
    ADDI r14,r14,0xa00
    LW r11,r28,1
    ADDI r12,r0,5
    LSL r11,r11,r12
    ADD r14,r14,r11
    LW r12,r14,0
    SW r12,r29,1
    ADDI r14,r14,1
    ADDI r15,r29,32
en_setup_copy:
    LW r11,r14,0
    SW r11,r15,0
    ADDI r14,r14,1
    ADDI r15,r15,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_setup_copy
    ADDI r11,r0,2
    SW r11,r28,0
    JMP en_start
en_name_send:
    ADDI r11,r0,9
    SW r11,r29,1
    ADDI r11,r0,0x0d
    SW r11,r29,32
    ADDI r11,r0,1
    SW r11,r29,33
    LUI r14,3
    ADDI r14,r14,0x900
    ADDI r15,r29,34
    ADDI r12,r0,7
en_name_copy:
    LW r11,r14,0
    SW r11,r15,0
    ADDI r14,r14,1
    ADDI r15,r15,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_name_copy
    ADDI r11,r0,4
    SW r11,r28,0
    JMP en_start
en_adv_send:
    ADDI r11,r0,5
    SW r11,r29,1
    ADDI r11,r0,0x0f
    SW r11,r29,32
    SW r0,r29,33
    SW r0,r29,34
    ADDI r11,r0,0x50
    SW r11,r29,35
    SW r0,r29,36
    ADDI r11,r0,6
    SW r11,r28,0
    JMP en_start
en_event:
    MOV r6,r16
    LW r11,r29,64
    ADDI r12,r0,0x81
    CMP r11,r12
    BEQ en_started
    ADDI r12,r0,0x84
    CMP r11,r12
    BEQ en_response
    ADDI r12,r0,0x85
    CMP r11,r12
    BEQ en_connected
    ADDI r12,r0,0x86
    CMP r11,r12
    BEQ en_disconnected
    ADDI r12,r0,0x88
    CMP r11,r12
    BEQ en_pipe
    ADDI r12,r0,0x8a
    CMP r11,r12
    BEQ en_credit
    ADDI r12,r0,0x8c
    CMP r11,r12
    BEQ en_receive
    ADDI r12,r0,0x8d
    CMP r11,r12
    BEQ en_event_fault
    ADDI r12,r0,0x83
    CMP r11,r12
    BEQ en_event_fault
en_event_ret:
    JR r6
en_started:
    LW r11,r29,67
    SW r11,r28,3
    SW r11,r28,2
    SW r0,r28,26
    LW r11,r29,65
    ADDI r12,r0,2
    CMP r11,r12
    BNE en_standby
    SW r0,r28,1
    ADDI r11,r0,1
    SW r11,r28,0
    JR r6
en_standby:
    ADDI r12,r0,3
    CMP r11,r12
    BNE en_event_fault
    SW r12,r28,0
    JR r6
en_response:
    LW r11,r29,65
    LW r12,r29,66
    ADDI r13,r0,6
    CMP r11,r13
    BNE en_rsp_other
    ADDI r13,r0,1
    CMP r12,r13
    BEQ en_setup_next
    ADDI r13,r0,2
    CMP r12,r13
    BNE en_event_fault
    ; Setup complete is followed by DEVICE_STARTED/STANDBY.
    SW r0,r28,0
    JR r6
en_setup_next:
    LW r11,r28,1
    ADDI r11,r11,1
    ADDI r12,r0,21
    CMP r11,r12
    BGE en_event_fault
    SW r11,r28,1
    ADDI r11,r0,1
    SW r11,r28,0
    JR r6
en_rsp_other:
    CMP r12,r0
    BNE en_event_fault
    ADDI r12,r0,0x0d
    CMP r11,r12
    BNE en_rsp_adv
    ADDI r11,r0,5
    SW r11,r28,0
    JR r6
en_rsp_adv:
    ADDI r12,r0,0x0f
    CMP r11,r12
    BNE en_event_ret
    ADDI r11,r0,7
    SW r11,r28,0
    JR r6
en_connected:
    ADDI r11,r0,1
    SW r11,r28,4
    SW r11,r28,7
    LW r11,r28,3
    SW r11,r28,2
    JR r6
en_disconnected:
    SW r0,r28,4
    SW r0,r28,5
    SW r0,r28,6
    SW r0,r28,12
    SW r0,r28,13
    SW r0,r28,14
    SW r0,r28,16
    ADDI r11,r0,5
    SW r11,r28,0
    JAL r16,en_clear_contacts
    JR r6
en_pipe:
    LW r11,r29,65
    ADDI r12,r0,8
    AND r11,r11,r12
    ADDI r12,r0,1
    CMP r11,r0
    BEQ en_pipe_set
    ADDI r12,r0,2
en_pipe_set:
    SW r12,r28,4
    ADDI r11,r0,1
    SW r11,r28,7
    JR r6
en_credit:
    LW r11,r29,65
    LW r12,r28,2
    ADD r12,r12,r11
    LW r11,r28,3
    CMP r12,r11
    BLT en_credit_set
    MOV r12,r11
en_credit_set:
    SW r12,r28,2
    JR r6
en_receive:
    LW r11,r29,65
    ADDI r12,r0,2
    CMP r11,r12
    BNE en_event_ret
    LW r12,r28,22
    ADDI r12,r12,-2
    CMP r12,r0
    BEQ en_event_ret
    BLT en_event_ret
    ADDI r11,r0,20
    CMP r11,r12
    BLT en_event_fault
en_rx_length:
    LW r13,r28,14
    ADD r11,r13,r12
    ADDI r14,r0,544
    CMP r11,r14
    BGE en_event_fault
    SW r11,r28,14
    ADD r14,r30,r13
    ADDI r15,r29,66
en_rx_copy:
    LW r11,r15,0
    SW r11,r14,0
    ADDI r14,r14,1
    ADDI r15,r15,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_rx_copy
    JR r6
en_event_fault:
    ADDI r11,r0,1
    SW r11,r28,26
    SW r11,r28,7
    ; Fail closed: do not silently ACK lost data. Exit/reopen resets the radio.
    SW r0,r28,4
    SW r0,r28,5
    SW r0,r28,0
    ADDI r11,r0,4
    SW r11,r29,0
    JR r6

; UI in a separate unused program region; all colors are ordinary 16-bit tiles.
.org 0x2400
en_entry:
    LUI r28,2
    ADDI r28,r28,0xe80
    ADDI r29,r9,256
    LUI r30,2
    ADDI r30,r30,0xc00
    LUI r31,2
    ADDI r31,r31,0xe20
    SW r23,r28,50
    SW r24,r28,51
    SW r25,r28,52
    SW r26,r28,53
    SW r27,r28,54
    MOV r11,r28
    ADDI r12,r0,50
en_init:
    SW r0,r11,0
    ADDI r11,r11,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_init
    ADDI r11,r0,97
    SW r11,r28,10
    ADDI r11,r0,1
    SW r11,r28,18
    SW r11,r28,7
    ADDI r11,r0,4
    SW r11,r29,0
    JAL r16,en_clear_contacts
en_loop:
    JAL r16,en_service
    JAL r16,en_parse
    JAL r16,en_retry
    LW r11,r28,7
    CMP r11,r0
    BEQ en_keys
    SW r0,r28,7
    JAL r16,en_draw
en_keys:
    LW r11,r9,1
    CMP r11,r0
    BEQ en_loop
    LW r1,r9,0
    LW r11,r28,9
    CMP r11,r0
    BNE en_edit_key
    ADDI r11,r0,0x11
    CMP r1,r11
    BEQ en_exit
    LW r12,r28,8
    ADDI r11,r0,0x1e
    CMP r1,r11
    BEQ en_contact_up
    ADDI r11,r0,0x1f
    CMP r1,r11
    BEQ en_contact_down
    ADDI r11,r0,0x0d
    CMP r1,r11
    BEQ en_open
    ADDI r11,r0,0x10
    CMP r1,r11
    BNE en_loop
en_open:
    LW r11,r28,15
    CMP r11,r0
    BEQ en_loop
    ADDI r11,r0,1
    SW r11,r28,9
    SW r11,r28,7
    JAL r16,en_selected
    SW r0,r4,1
    ; OPEN_CHAT is optional in current Apple bridge; it can be ignored there.
    LW r11,r28,12
    CMP r11,r0
    BNE en_loop
    LW r2,r4,0
    ADDI r1,r0,5
    ZERO r3
    JAL r16,en_queue
    JMP en_loop
en_contact_up:
    ADDI r12,r12,-1
    CMP r12,r0
    BGE en_select
    LW r12,r28,15
    ADDI r12,r12,-1
    CMP r12,r0
    BGE en_select
    ZERO r12
    JMP en_select
en_contact_down:
    ADDI r12,r12,1
    LW r11,r28,15
    CMP r12,r11
    BLT en_select
    ZERO r12
en_select:
    SW r12,r28,8
en_dirty:
    ADDI r11,r0,1
    SW r11,r28,7
    JMP en_loop
en_edit_key:
    ADDI r11,r0,0x11
    CMP r1,r11
    BEQ en_leave_chat
    ADDI r11,r0,0x10
    CMP r1,r11
    BEQ en_send
    ADDI r11,r0,0x0d
    CMP r1,r11
    BEQ en_append
    LW r12,r28,10
    ADDI r11,r0,0x1e
    CMP r1,r11
    BEQ en_char_up
    ADDI r12,r12,-1
    ADDI r11,r0,32
    CMP r12,r11
    BGE en_char_set
    ADDI r12,r0,127
    JMP en_char_set
en_char_up:
    ADDI r12,r12,1
    ADDI r11,r0,128
    CMP r12,r11
    BLT en_char_set
    ADDI r12,r0,32
en_char_set:
    SW r12,r28,10
    JMP en_dirty
en_leave_chat:
    SW r0,r28,9
    JMP en_dirty
en_append:
    LW r12,r28,11
    LW r13,r28,10
    ADDI r11,r0,127
    CMP r13,r11
    BEQ en_backspace
    ADDI r11,r0,40
    CMP r12,r11
    BGE en_loop
    ADDI r14,r28,64
    ADD r14,r14,r12
    SW r13,r14,0
    SW r0,r14,1
    ADDI r12,r12,1
    SW r12,r28,11
    JMP en_dirty
en_backspace:
    CMP r12,r0
    BEQ en_loop
    ADDI r12,r12,-1
    SW r12,r28,11
    ADDI r14,r28,64
    ADD r14,r14,r12
    SW r0,r14,0
    JMP en_dirty
en_send:
    JAL r16,en_send_draft
    JMP en_dirty
en_exit:
    ADDI r11,r0,4
    SW r11,r29,0
    LW r23,r28,50
    LW r24,r28,51
    LW r25,r28,52
    LW r26,r28,53
    LW r27,r28,54
    JMP main_loop

en_selected:
    LW r4,r28,8
    ADDI r11,r0,7
    LSL r4,r4,r11
    LUI r11,2
    ADDI r11,r11,0x800
    ADD r4,r4,r11
    JR r16
; r4 string-table index. Tail call preserves normal puts ABI.
en_text:
    LUI r11,3
    ADDI r11,r11,0xd00
    ADD r11,r11,r4
    LW r4,r11,0
    JMP puts
en_draw:
    MOV r22,r16
    ADDI r11,r0,12
    ADDI r23,r0,15
    LSL r23,r23,r11
    ADDI r24,r0,2
    LSL r24,r24,r11
    ADDI r24,r24,0xf00
    ADDI r25,r0,14
    LSL r25,r25,r11
    ADDI r26,r0,10
    LSL r26,r26,r11
    ADDI r27,r0,9
    LSL r27,r27,r11
    ADDI r27,r27,0xf00
    ADDI r3,r23,32
    JAL r16,cls
    ZERO r1
    ZERO r2
    ADDI r3,r24,32
    ADDI r4,r0,80
    ADDI r5,r0,5
    JAL r16,ui_rect
    ADDI r1,r0,2
    ADDI r2,r0,2
    MOV r5,r24
    ZERO r4
    JAL r16,en_text
    ADDI r4,r0,1
    LW r11,r28,4
    CMP r11,r0
    BEQ en_link_text
    ADDI r4,r0,2
    LW r11,r28,5
    CMP r11,r0
    BEQ en_link_text
    ADDI r4,r0,3
    LW r11,r28,6
    ADDI r12,r0,2
    CMP r11,r12
    BNE en_link_text
    ADDI r4,r0,4
en_link_text:
    LW r11,r28,26
    CMP r11,r0
    BEQ en_link_ok
    ADDI r4,r0,5
en_link_ok:
    ADDI r1,r0,52
    ADDI r2,r0,2
    MOV r5,r24
    JAL r16,en_text
    ADDI r1,r0,2
    ADDI r2,r0,7
    MOV r5,r23
    ADDI r4,r0,6
    JAL r16,en_text
    ZERO r18
en_draw_contacts:
    LW r11,r28,15
    CMP r18,r11
    BGE en_draw_chat
    ADDI r11,r0,3
    MUL r19,r18,r11
    ADDI r19,r19,10
    MOV r21,r23
    LW r11,r28,8
    CMP r18,r11
    BNE en_contact_bg
    MOV r21,r27
en_contact_bg:
    ADDI r1,r0,1
    MOV r2,r19
    ADDI r3,r21,32
    ADDI r4,r0,21
    ADDI r5,r0,3
    JAL r16,ui_rect
    ADDI r11,r0,7
    LSL r4,r18,r11
    LUI r11,2
    ADDI r11,r11,0x804
    ADD r4,r4,r11
    ; Compact rows, left aligned, one row of vertical padding.
    ADDI r1,r0,2
    ADDI r2,r19,1
    MOV r5,r21
    ADDI r3,r0,19
    JAL r16,en_putn
    ADDI r18,r18,1
    JMP en_draw_contacts
en_draw_chat:
    ; Existing single-pixel CP437 outlines, pale grey on white.
    ADDI r1,r0,0
    ADDI r2,r0,6
    ADDI r3,r0,24
    ADDI r4,r0,46
    ADDI r5,r23,0x700
    JAL r16,box
    LW r11,r28,15
    CMP r11,r0
    BNE en_has_contacts
    ADDI r1,r0,27
    ADDI r2,r0,12
    MOV r5,r23
    ADDI r4,r0,7
    JAL r16,en_text
    JMP en_draw_footer
en_has_contacts:
    JAL r16,en_selected
    MOV r18,r4
    ADDI r4,r4,4
    ADDI r1,r0,27
    ADDI r2,r0,7
    MOV r5,r23
    JAL r16,puts
    ADDI r1,r0,27
    ADDI r2,r0,19
    ADDI r3,r25,32
    ADDI r4,r0,47
    ADDI r5,r0,7
    JAL r16,ui_rect
    ADDI r1,r0,27
    ADDI r2,r0,19
    ADDI r3,r0,47
    ADDI r4,r0,7
    ADDI r5,r25,0x600
    JAL r16,box
    ADDI r1,r0,29
    ADDI r2,r0,20
    MOV r5,r25
    ADDI r4,r0,8
    JAL r16,en_text
    ADDI r1,r0,29
    ADDI r2,r0,23
    ADDI r4,r18,40
    MOV r5,r25
    JAL r16,puts
    ; Two white rows separate the colored messages and their thin outlines.
    ADDI r1,r0,31
    ADDI r2,r0,28
    ADDI r3,r26,32
    ADDI r4,r0,47
    ADDI r5,r0,7
    JAL r16,ui_rect
    ADDI r1,r0,31
    ADDI r2,r0,28
    ADDI r3,r0,47
    ADDI r4,r0,7
    ADDI r5,r26,0x200
    JAL r16,box
    ADDI r1,r0,33
    ADDI r2,r0,29
    MOV r5,r26
    ADDI r4,r0,9
    JAL r16,en_text
    ADDI r1,r0,33
    ADDI r2,r0,32
    ADDI r4,r18,84
    MOV r5,r26
    JAL r16,puts
    ADDI r1,r0,26
    ADDI r2,r0,39
    ADDI r3,r0,52
    ADDI r4,r0,5
    ADDI r5,r23,0x700
    JAL r16,box
    ADDI r1,r0,27
    ADDI r2,r0,38
    MOV r5,r23
    ADDI r4,r0,10
    JAL r16,en_text
    ADDI r1,r0,27
    ADDI r2,r0,41
    ADDI r4,r28,64
    MOV r5,r23
    JAL r16,puts
    ADDI r1,r0,27
    ADDI r2,r0,46
    MOV r5,r23
    ADDI r4,r0,11
    JAL r16,en_text
    LW r12,r28,10
    ADDI r11,r0,127
    CMP r12,r11
    BNE en_show_char
    ADDI r12,r0,60
en_show_char:
    OR r12,r12,r27
    ADDI r11,r0,46
    MUL r11,r11,r10
    ADD r11,r11,r8
    SW r12,r11,40
    LW r11,r28,16
    CMP r11,r0
    BEQ en_draw_footer
    ADDI r1,r0,27
    ADDI r2,r0,50
    MOV r5,r23
    ADDI r4,r0,12
    JAL r16,en_text
en_draw_footer:
    ADDI r1,r0,2
    ADDI r2,r0,55
    MOV r5,r23
    ADDI r4,r0,13
    LW r11,r28,9
    CMP r11,r0
    BEQ en_footer_selected
    ADDI r4,r0,14
en_footer_selected:
    JAL r16,en_text
    ADDI r1,r0,2
    ADDI r2,r0,58
    MOV r5,r23
    ADDI r4,r0,15
    JAL r16,en_text
    JR r22
en_putn:
    MUL r11,r2,r10
    ADD r11,r11,r1
    ADD r11,r11,r8
en_putn_loop:
    LW r12,r4,0
    CMP r12,r0
    BEQ en_putn_ret
    OR r12,r12,r5
    SW r12,r11,0
    ADDI r4,r4,1
    ADDI r11,r11,1
    ADDI r3,r3,-1
    CMP r3,r0
    BNE en_putn_loop
en_putn_ret:
    JR r16

.org 0x2800
en_contacts: .space 1024
.org 0x2c00
en_rx: .space 544
.org 0x2e20
en_tx: .space 64
.org 0x2e80
en_state: .space 64
en_draft: .space 41
.org 0x2f00
en_scratch: .space 64
.org 0x2f80
en_dedup: .space 128
.org 0x3d00
.word en_s_title,en_s_offline,en_s_ble,en_s_ready,en_s_online,en_s_error
.word en_s_contacts,en_s_empty,en_s_rx,en_s_tx,en_s_message,en_s_character
.word en_s_pending,en_s_nav,en_s_edit,en_s_limit
en_s_title: .asciz "Envelop"
en_s_offline: .asciz "Bridge offline"
en_s_ble: .asciz "BLE connected"
en_s_ready: .asciz "Bridge verified"
en_s_online: .asciz "Bridge online"
en_s_error: .asciz "Radio error - reopen"
en_s_contacts: .asciz "CONTACTS"
en_s_empty: .asciz "Connect Envelop on your phone."
en_s_rx: .asciz "RECEIVED"
en_s_tx: .asciz "YOU"
en_s_message: .asciz "MESSAGE"
en_s_character: .asciz "Character:"
en_s_pending: .asciz "Waiting for server ACK..."
en_s_nav: .asciz "UP/DOWN contact   CENTER chat   LEFT exit"
en_s_edit: .asciz "UP/DOWN character   CENTER add   RIGHT send   LEFT contacts"
en_s_limit: .asciz "40 characters   < = delete   Keep this app open for Bluetooth"
.org 0x3f00
en_identity: .asciz "ENVELOP/1\nDEVICE=TOMATO\nID=TOMATO-001"

; Streaming ENVELOP/1 parser + small projection. Maximum wire payload 512.
; Corrupt headers/CRC advance ONE byte; partial frames survive until disconnect.
.org 0x19a0
en_parse:
    MOV r17,r16
    LW r11,r28,12
    CMP r11,r0
    BNE en_parse_ret
    LW r11,r28,14
    ADDI r12,r0,8
    CMP r11,r12
    BLT en_parse_ret
    LW r11,r30,0
    ADDI r12,r0,0x50
    CMP r11,r12
    BNE en_bad
    LW r11,r30,1
    ADDI r12,r0,0x47
    CMP r11,r12
    BNE en_bad
    LW r11,r30,2
    ADDI r12,r0,1
    CMP r11,r12
    BNE en_bad
    LW r11,r30,3
    ADDI r12,r0,32
    CMP r11,r12
    BEQ en_parse_type_ok
    ADDI r12,r0,1
    CMP r11,r12
    BLT en_bad
    ADDI r12,r0,13
    CMP r11,r12
    BGE en_bad
en_parse_type_ok:
    LW r2,r30,6
    ADDI r11,r0,8
    LSL r2,r2,r11
    LW r11,r30,7
    OR r2,r2,r11
    ADDI r11,r0,512
    CMP r11,r2
    BLT en_bad
    ADDI r11,r2,10
    LW r12,r28,14
    CMP r12,r11
    BLT en_parse_ret
    SW r11,r28,41
    ADDI r2,r2,8
    MOV r1,r30
    JAL r16,en_crc
    LW r11,r28,41
    ADD r11,r11,r30
    LW r12,r11,-2
    ADDI r13,r0,8
    LSL r12,r12,r13
    LW r13,r11,-1
    OR r12,r12,r13
    CMP r12,r3
    BNE en_bad
    JAL r16,en_dispatch
    LW r1,r28,41
    JMP en_consume
en_bad:
    ADDI r1,r0,1
en_consume:
    LW r2,r28,14
    SUB r2,r2,r1
    SW r2,r28,14
    ADD r11,r30,r1
    MOV r12,r30
en_shift:
    CMP r2,r0
    BEQ en_parse_ret
    LW r13,r11,0
    SW r13,r12,0
    ADDI r11,r11,1
    ADDI r12,r12,1
    ADDI r2,r2,-1
    JMP en_shift
en_parse_ret:
    JR r17

; CRC16/CCITT-FALSE. r1 words of bytes, r2 count -> r3 checksum.
en_crc:
    ADDI r3,r0,-1
    ADDI r14,r0,16
    LSR r3,r3,r14
    ADDI r14,r0,0x102
    ADDI r15,r0,4
    LSL r14,r14,r15
    ADDI r14,r14,1
en_crc_byte:
    CMP r2,r0
    BEQ en_crc_ret
    LW r11,r1,0
    ADDI r12,r0,8
    LSL r11,r11,r12
    XOR r3,r3,r11
en_crc_bit:
    ADDI r15,r0,15
    LSR r11,r3,r15
    ADDI r15,r0,1
    AND r11,r11,r15
    LSL r3,r3,r15
    CMP r11,r0
    BEQ en_crc_no_xor
    XOR r3,r3,r14
en_crc_no_xor:
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_crc_bit
    ADDI r15,r0,16
    LSL r3,r3,r15
    LSR r3,r3,r15
    ADDI r1,r1,1
    ADDI r2,r2,-1
    JMP en_crc_byte
en_crc_ret:
    JR r16

; Queue at most 54 bytes. Caller checks TX idle. r1 type,r2 route,r3 len,r4 data.
en_queue:
    MOV r5,r16
    ADDI r11,r0,0x50
    SW r11,r31,0
    ADDI r11,r0,0x47
    SW r11,r31,1
    ADDI r11,r0,1
    SW r11,r31,2
    SW r1,r31,3
    ADDI r11,r0,8
    LSR r12,r2,r11
    SW r12,r31,4
    ADDI r11,r0,255
    AND r12,r2,r11
    SW r12,r31,5
    SW r0,r31,6
    SW r3,r31,7
    ADDI r12,r3,10
    SW r12,r28,12
    SW r0,r28,13
    ADDI r12,r31,8
    MOV r13,r3
en_queue_copy:
    CMP r13,r0
    BEQ en_queue_crc
    LW r11,r4,0
    SW r11,r12,0
    ADDI r4,r4,1
    ADDI r12,r12,1
    ADDI r13,r13,-1
    JMP en_queue_copy
en_queue_crc:
    ADDI r2,r3,8
    MOV r1,r31
    JAL r16,en_crc
    LW r11,r28,12
    ADD r11,r11,r31
    ADDI r12,r0,8
    LSR r12,r3,r12
    ; SW zero-extends imm8, so negative offsets would land +254 ahead.
    ; Step the pointer explicitly instead.
    ADDI r11,r11,-2
    SW r12,r11,0
    ADDI r11,r11,1
    ADDI r12,r0,255
    AND r3,r3,r12
    SW r3,r11,0
    JR r5

en_dispatch:
    MOV r19,r16
    LW r21,r30,3
    LW r22,r30,4
    ADDI r11,r0,8
    LSL r22,r22,r11
    LW r11,r30,5
    OR r22,r22,r11
    LW r23,r30,6
    ADDI r11,r0,8
    LSL r23,r23,r11
    LW r11,r30,7
    OR r23,r23,r11
    ADDI r11,r0,1
    CMP r21,r11
    BEQ en_hello
    LW r11,r28,5
    CMP r11,r0
    BEQ en_dispatch_ret
    ADDI r11,r0,3
    CMP r21,r11
    BEQ en_contact_reset
    ADDI r11,r0,11
    CMP r21,r11
    BEQ en_ping
    ADDI r11,r0,10
    CMP r21,r11
    BEQ en_status
    CMP r22,r0
    BEQ en_dispatch_ret
    MOV r1,r22
    JAL r16,en_find
    MOV r25,r4
    ADDI r11,r0,4
    CMP r21,r11
    BEQ en_upsert
    CMP r25,r0
    BEQ en_dispatch_ret
    ADDI r11,r0,32
    CMP r21,r11
    BEQ remote_exec
    ADDI r11,r0,9
    CMP r21,r11
    BEQ en_ack_received
    ADDI r11,r0,6
    CMP r21,r11
    BEQ en_message
    ADDI r11,r0,7
    CMP r21,r11
    BEQ en_message
en_dispatch_ret:
    JR r19
en_hello:
    OR r11,r22,r23
    CMP r11,r0
    BNE en_dispatch_ret
    LW r11,r28,4
    ADDI r12,r0,2
    CMP r11,r12
    BNE en_dispatch_ret
    ADDI r11,r0,1
    SW r11,r28,5
    SW r11,r28,7
    ADDI r1,r0,2
    ZERO r2
    ADDI r3,r0,37
    LUI r4,3
    ADDI r4,r4,0xf00
    JAL r16,en_queue
    JR r19
en_contact_reset:
    OR r11,r22,r23
    CMP r11,r0
    BNE en_dispatch_ret
    JAL r16,en_clear_contacts
    JR r19
en_ping:
    CMP r22,r0
    BNE en_dispatch_ret
    ADDI r11,r0,9
    CMP r23,r11
    BGE en_dispatch_ret
    ADDI r1,r0,12
    ZERO r2
    MOV r3,r23
    ADDI r4,r30,8
    JAL r16,en_queue
    JR r19
en_status:
    CMP r22,r0
    BNE en_dispatch_ret
    ADDI r11,r0,1
    CMP r23,r11
    BNE en_dispatch_ret
    LW r12,r30,8
    ADDI r13,r0,3
    CMP r12,r13
    BGE en_dispatch_ret
    SW r12,r28,6
    SW r11,r28,7
    JR r19
en_upsert:
    ADDI r11,r0,3
    CMP r23,r11
    BLT en_dispatch_ret
    ADDI r11,r0,35
    CMP r23,r11
    BGE en_dispatch_ret
    LW r11,r30,8
    ADDI r12,r0,16
    CMP r11,r12
    BGE en_dispatch_ret
    LW r11,r30,9
    ADDI r12,r0,2
    CMP r11,r12
    BGE en_dispatch_ret
    ADDI r4,r30,10
    ADDI r3,r23,-2
    JAL r16,en_printable
    CMP r1,r0
    BEQ en_dispatch_ret
    CMP r25,r0
    BNE en_upsert_copy
    LW r11,r28,15
    ADDI r12,r0,8
    CMP r11,r12
    BGE en_dispatch_ret
    ADDI r12,r0,7
    LSL r25,r11,r12
    LUI r12,2
    ADDI r12,r12,0x800
    ADD r25,r25,r12
    ADDI r11,r11,1
    SW r11,r28,15
    SW r22,r25,0
en_upsert_copy:
    LW r11,r30,9
    SW r11,r25,1
    ADDI r11,r25,4
    ADDI r12,r30,10
    ADDI r13,r23,-2
en_name_project:
    LW r14,r12,0
    SW r14,r11,0
    ADDI r11,r11,1
    ADDI r12,r12,1
    ADDI r13,r13,-1
    CMP r13,r0
    BNE en_name_project
    SW r0,r11,0
    ADDI r11,r0,1
    SW r11,r28,7
    JR r19
en_message:
    ADDI r26,r0,4
    ADDI r11,r0,6
    CMP r21,r11
    BNE en_msg_length
    ADDI r26,r0,5
    LW r11,r30,12
    ADDI r12,r0,2
    CMP r11,r12
    BGE en_dispatch_ret
en_msg_length:
    SUB r27,r23,r26
    CMP r27,r0
    BEQ en_dispatch_ret
    BLT en_dispatch_ret
    ADDI r11,r0,257
    CMP r27,r11
    BGE en_dispatch_ret
    ADDI r4,r30,8
    ADD r4,r4,r26
    MOV r3,r27
    JAL r16,en_printable
    CMP r1,r0
    BEQ en_dispatch_ret
    JAL r16,en_token
    MOV r24,r1
    ; Bounded dedup ring: (route,token), 64 entries, never auto-reply on history.
    LUI r11,2
    ADDI r11,r11,0xf80
    LW r12,r28,23
en_dedup_search:
    CMP r12,r0
    BEQ en_new_message
    LW r13,r11,0
    CMP r13,r22
    BNE en_dedup_next
    LW r13,r11,1
    CMP r13,r24
    BEQ en_ack_message
en_dedup_next:
    ADDI r11,r11,2
    ADDI r12,r12,-1
    JMP en_dedup_search
en_new_message:
    LW r12,r28,24
    ADD r12,r12,r12
    LUI r11,2
    ADDI r11,r11,0xf80
    ADD r11,r11,r12
    SW r22,r11,0
    SW r24,r11,1
    LW r12,r28,24
    ADDI r12,r12,1
    ADDI r13,r0,63
    AND r12,r12,r13
    SW r12,r28,24
    LW r12,r28,23
    ADDI r13,r0,64
    CMP r12,r13
    BGE en_project
    ADDI r12,r12,1
    SW r12,r28,23
en_project:
    ADDI r11,r0,1
    SW r11,r28,7
    SW r11,r25,1
    ADDI r12,r25,40
    ADDI r13,r0,6
    CMP r21,r13
    BNE en_project_rx
    LW r13,r30,12
    CMP r13,r0
    BEQ en_project_rx
    LW r13,r28,16
    CMP r13,r0
    BEQ en_project_tx
    LW r13,r28,17
    CMP r13,r22
    BEQ en_dispatch_ret
en_project_tx:
    ADDI r12,r25,84
en_project_rx:
    ADDI r13,r30,8
    ADD r13,r13,r26
    MOV r14,r27
    ADDI r15,r0,40
    CMP r14,r15
    BLT en_project_copy
    MOV r14,r15
en_project_copy:
    LW r11,r13,0
    SW r11,r12,0
    ADDI r13,r13,1
    ADDI r12,r12,1
    ADDI r14,r14,-1
    CMP r14,r0
    BNE en_project_copy
    SW r0,r12,0
    ADDI r11,r0,40
    CMP r11,r27
    BGE en_maybe_greet
    ADDI r11,r0,46
    ; SW zero-extends imm8: walk the pointer instead of negative offsets.
    ADDI r12,r12,-3
    SW r11,r12,0
    ADDI r12,r12,1
    SW r11,r12,0
    ADDI r12,r12,1
    SW r11,r12,0
en_maybe_greet:
    ADDI r11,r0,7
    CMP r21,r11
    BNE en_ack_message
    JAL r16,remote_chat
en_ack_message:
    ADDI r11,r0,7
    CMP r21,r11
    BNE en_dispatch_ret
    ADDI r1,r0,9
    MOV r2,r22
    ADDI r3,r0,4
    ADDI r4,r30,8
    JAL r16,en_queue
    JR r19
en_ack_received:
    ADDI r11,r0,4
    CMP r23,r11
    BNE en_dispatch_ret
    JAL r16,en_token
    LW r11,r28,16
    CMP r1,r11
    BNE en_dispatch_ret
    LW r11,r28,17
    CMP r22,r11
    BNE en_dispatch_ret
    SW r0,r28,16
    ADDI r11,r0,1
    SW r11,r28,7
    JR r19
; Four big-endian token bytes at RX+8 -> r1 (opaque, zero also legal).
en_token:
    ZERO r1
    ADDI r11,r30,8
    ADDI r12,r0,4
    ADDI r14,r0,8
en_token_loop:
    LSL r1,r1,r14
    LW r13,r11,0
    OR r1,r1,r13
    ADDI r11,r11,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_token_loop
    JR r16
en_find:
    LUI r4,2
    ADDI r4,r4,0x800
    LW r11,r28,15
en_find_loop:
    CMP r11,r0
    BEQ en_find_none
    LW r12,r4,0
    CMP r12,r1
    BEQ en_find_ret
    ADDI r4,r4,128
    ADDI r11,r11,-1
    JMP en_find_loop
en_find_none:
    ZERO r4
en_find_ret:
    JR r16
en_printable:
    ADDI r12,r0,32
    ADDI r13,r0,127
    ZERO r1
en_printable_loop:
    CMP r3,r0
    BEQ en_printable_yes
    LW r11,r4,0
    CMP r11,r12
    BLT en_printable_ret
    CMP r11,r13
    BGE en_printable_ret
    ADDI r4,r4,1
    ADDI r3,r3,-1
    JMP en_printable_loop
en_printable_yes:
    ADDI r1,r0,1
en_printable_ret:
    JR r16
en_clear_contacts:
    LUI r11,2
    ADDI r11,r11,0x800
    ADDI r12,r0,1024
en_clear_loop:
    SW r0,r11,0
    ADDI r11,r11,1
    ADDI r12,r12,-1
    CMP r12,r0
    BNE en_clear_loop
    SW r0,r28,8
    SW r0,r28,9
    SW r0,r28,11
    SW r0,r28,15
    SW r0,r28,16
    SW r0,r28,23
    SW r0,r28,24
    SW r0,r28,44
    SW r0,r28,45
    SW r0,r28,64
    ADDI r11,r0,1
    SW r11,r28,7
    JR r16

; One outgoing message in flight. Retransmit SAME token/body every 3 seconds.
en_send_draft:
    SW r16,r28,42
    LW r11,r28,5
    CMP r11,r0
    BEQ en_send_ret
    LW r11,r28,12
    LW r12,r28,16
    OR r11,r11,r12
    CMP r11,r0
    BNE en_send_ret
    LW r11,r28,11
    CMP r11,r0
    BEQ en_send_ret
    LW r11,r28,18
    CMP r11,r0
    BEQ en_send_ret
    SW r11,r28,16
    ADDI r11,r11,1
    SW r11,r28,18
    JAL r16,en_selected
    LW r11,r4,0
    SW r11,r28,17
    LW r13,r28,11
    SW r13,r4,3
    ADDI r12,r28,64
    ADDI r4,r4,84
en_draft_copy:
    LW r11,r12,0
    SW r11,r4,0
    ADDI r4,r4,1
    ADDI r12,r12,1
    ADDI r13,r13,-1
    CMP r13,r0
    BNE en_draft_copy
    SW r0,r4,0
    SW r0,r28,11
    SW r0,r28,64
    JAL r16,en_outgoing
en_send_ret:
    LW r16,r28,42
    JR r16
en_retry:
    LW r11,r28,12
    CMP r11,r0
    BNE en_retry_ret
    LW r11,r28,16
    CMP r11,r0
    BEQ remote_followup
    LW r11,r9,2
    LW r12,r28,19
    SUB r11,r11,r12
    ADDI r12,r0,3000
    CMP r11,r12
    BLT en_retry_ret
    JMP en_outgoing
en_retry_ret:
    JR r16
en_outgoing:
    SW r16,r28,43
    LW r1,r28,17
    JAL r16,en_find
    CMP r4,r0
    BEQ en_outgoing_ret
    MOV r18,r4
    LUI r4,2
    ADDI r4,r4,0xf00
    LW r11,r28,16
    ADDI r12,r0,24
    LSR r13,r11,r12
    SW r13,r4,0
    ADDI r12,r0,16
    LSR r13,r11,r12
    ADDI r14,r0,255
    AND r13,r13,r14
    SW r13,r4,1
    ADDI r12,r0,8
    LSR r13,r11,r12
    AND r13,r13,r14
    SW r13,r4,2
    AND r13,r11,r14
    SW r13,r4,3
    ADDI r12,r4,4
    ADDI r13,r18,84
    LW r3,r18,3
    MOV r14,r3
en_out_copy:
    LW r11,r13,0
    SW r11,r12,0
    ADDI r12,r12,1
    ADDI r13,r13,1
    ADDI r14,r14,-1
    CMP r14,r0
    BNE en_out_copy
    ADDI r3,r3,4
    LW r2,r28,17
    ADDI r1,r0,8
    JAL r16,en_queue
    LW r11,r9,2
    SW r11,r28,19
en_outgoing_ret:
    LW r16,r28,43
    JR r16

; Auto-reply only to a new live Hi/Hey/Hello (case insensitive), once per
; deduplicated delivery. Never to history; never overwrite an in-flight send.
en_greet:
    LW r11,r28,16
    CMP r11,r0
    BNE en_greet_ret
    LW r11,r30,12
    ADDI r15,r0,32
    OR r11,r11,r15
    ADDI r12,r0,104
    CMP r11,r12
    BNE en_greet_ret
    LW r11,r30,13
    OR r11,r11,r15
    ADDI r12,r0,2
    CMP r27,r12
    BNE en_greet_long
    ADDI r12,r0,105
    CMP r11,r12
    BEQ en_greet_make
    JR r16
en_greet_long:
    ADDI r12,r0,101
    CMP r11,r12
    BNE en_greet_ret
    LW r11,r30,14
    OR r11,r11,r15
    ADDI r12,r0,3
    CMP r27,r12
    BNE en_greet_hello
    ADDI r12,r0,121
    CMP r11,r12
    BEQ en_greet_make
    JR r16
en_greet_hello:
    ADDI r12,r0,5
    CMP r27,r12
    BNE en_greet_ret
    ADDI r12,r0,108
    CMP r11,r12
    BNE en_greet_ret
    LW r11,r30,15
    OR r11,r11,r15
    CMP r11,r12
    BNE en_greet_ret
    LW r11,r30,16
    OR r11,r11,r15
    ADDI r12,r0,111
    CMP r11,r12
    BNE en_greet_ret
en_greet_make:
    ; Personality follow-ups use states 6 -> 5 -> 4 after each server ACK.
    ADDI r11,r0,6
    SW r11,r28,44
    SW r22,r28,45
    LW r11,r28,18
    CMP r11,r0
    BEQ en_greet_ret
    SW r11,r28,16
    ADDI r11,r11,1
    SW r11,r28,18
    SW r22,r28,17
    LUI r11,3
    ADDI r11,r11,0xf40
    ADDI r12,r25,84
    ADDI r13,r0,7
en_greet_prefix:
    LW r14,r11,0
    SW r14,r12,0
    ADDI r11,r11,1
    ADDI r12,r12,1
    ADDI r13,r13,-1
    CMP r13,r0
    BNE en_greet_prefix
    ADDI r11,r25,4
    ADDI r13,r0,7
    ADDI r15,r0,20
en_greet_name:
    CMP r15,r0
    BEQ en_greet_suffix_start
    LW r14,r11,0
    CMP r14,r0
    BEQ en_greet_suffix_start
    ADDI r1,r0,32
    CMP r14,r1
    BEQ en_greet_suffix_start
    SW r14,r12,0
    ADDI r12,r12,1
    ADDI r11,r11,1
    ADDI r13,r13,1
    ADDI r15,r15,-1
    JMP en_greet_name
en_greet_suffix_start:
    LUI r11,3
    ADDI r11,r11,0xf50
en_greet_suffix:
    LW r14,r11,0
    CMP r14,r0
    BEQ en_greet_done
    SW r14,r12,0
    ADDI r12,r12,1
    ADDI r11,r11,1
    ADDI r13,r13,1
    JMP en_greet_suffix
en_greet_done:
    SW r0,r12,0
    SW r13,r25,3
    LW r11,r9,2
    ADDI r11,r11,-3000
    SW r11,r28,19
en_greet_ret:
    JR r16
.org 0x3f40
en_greeting: .asciz "Hello, "
.org 0x3f50
en_greeting_suffix: .asciz "! I'm Tomato."
