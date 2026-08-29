; ============================================================================
; Tomato OS — the shell that puts the machine on a screen
;
; Target : Tomato 32-bit CPU on Nexys A7-100T, 12-bit DVI PMOD (JC + JD)
; Build  : make -C hardware/fpga/core burn BOOT=tomato_os
; ISA    : docs/isa/tomato.v1.csv
;
; SPDX-License-Identifier: CERN-OHL-P-2.0
;
; Display contract (rtl/board/videoout.v):
;   framebuffer word at 0x300000 + y*80 + x, 80x60 cells of 8x8 pixels
;     [ 7: 0] glyph   CP437-ish code
;     [11: 8] fg      palette index
;     [15:12] bg      palette index
;   A word with [15:8] == 0 is a legacy SOLID cell in palette[3:0].
;   Any tile with a black background is one ADDI, since 0x0FFF < 4096.
;
; Keyboard contract (rtl/board/keypad.v via MMIO 0x780000):
;   word 0 = keycode (reading it consumes the key), word 1 = ready flag
;   0x1E up   0x1F down   0x11 left   0x10 right   0x0D enter
;   Those four codes are also their own glyphs, so a keycode can be drawn.
;
; Memory map — everything an LA reaches has to sit under 4096.
;   0x0000  code
;   0x0590  strings, string tables, jump table, tetromino table
;   0x0E00  tunables the bench pokes before reset (game speeds, boot)
;   0x0E08  scratch and mutable state
;   0x0E20  tetris board, one 10-bit row mask per word
;   0x0E40  snake body ring, 128 packed cells
;
; Register map
;   r0            zero
;   r1..r5        helper arguments (clobbered)
;   r6,r7         caller temporaries — also game state (direction, piece x/y)
;   r8            framebuffer base      0x300000
;   r9            keyboard base         0x780000
;   r10           80, the row stride
;   r11..r15      helper scratch
;   r16           link register (JAL r16 / JR r16) — helpers are all leaves
;   r17           link save for composites (a composite never calls a composite)
;   r18,r19       screen loop counters — also game state
;   r20           menu selection, preserved across every screen
;   r21,r22       screen scratch — also game state
;   r23..r27      attribute constants
;   r28..r31      game scratch that survives a helper call
; ============================================================================

; ---- boot ------------------------------------------------------------------
            ZERO    r0
            LUI     r8, 0x300           ; framebuffer window  [21:19] = 110
            LUI     r9, 0x780           ; keyboard window     [21:19] = 111
            ADDI    r10, r0, 80

            ; Attributes with a black background fit in one ADDI; the two that
            ; need a real background get shifted into place here, once.
            ADDI    r24, r0, 0x0F00     ; white on black   — body text
            ADDI    r26, r0, 0x0E00     ; gold on black    — headings
            ADDI    r27, r0, 0x0700     ; silver on black  — chrome
            ADDI    r6, r0, 12
            ADDI    r25, r0, 4
            LSL     r25, r25, r6
            OR      r25, r25, r24       ; 0x4F00 white on tomato — title bar
            ADDI    r23, r0, 9
            LSL     r23, r23, r6
            OR      r23, r23, r24       ; 0x9F00 white on sky    — selection

            ZERO    r20                 ; menu starts on the first entry
            JAL     r16, splash         ; once, before the desktop ever paints

; ---- main loop -------------------------------------------------------------
main_loop:
            JAL     r16, draw_desktop
menu_redraw:
            JAL     r16, draw_menu
menu_wait:
            JAL     r16, getkey
            MOV     r21, r1

            ADDI    r6, r0, 0x1E        ; up
            CMP     r21, r6
            BEQ     menu_up
            ADDI    r6, r0, 0x1F        ; down
            CMP     r21, r6
            BEQ     menu_down
            ADDI    r6, r0, 0x0D        ; enter
            CMP     r21, r6
            BEQ     menu_enter
            JMP     menu_wait

menu_up:
            ADDI    r20, r20, -1
            CMP     r20, r0
            BGE     menu_redraw
            LA      r6, n_menu
            LW      r20, r6, 0
            ADDI    r20, r20, -1
            JMP     menu_redraw

menu_down:
            ADDI    r20, r20, 1
            LA      r6, n_menu
            LW      r6, r6, 0
            CMP     r20, r6
            BLT     menu_redraw
            ZERO    r20
            JMP     menu_redraw

; ENTER opens the highlighted entry. One indexed load beats a chain of
; compares, and adding a screen is then a line in the table.
menu_enter:
            LA      r6, menu_targets
            ADD     r6, r6, r20
            LW      r6, r6, 0
            JR      r6

; ============================================================================
; Screens
; ============================================================================

; ---- system info -----------------------------------------------------------
screen_sysinfo:
            LA      r4, s_sysinfo
            JAL     r16, screen_frame

            ADDI    r1, r0, 6
            ADDI    r2, r0, 8
            MOV     r5, r26
            LA      r4, s_si_h1
            JAL     r16, puts

            LA      r19, si_body        ; table of string pointers
            ADDI    r18, r0, 10         ; first body row
si_line:
            LW      r22, r19, 0
            CMP     r22, r0
            BEQ     si_done
            ADDI    r1, r0, 8
            MOV     r2, r18
            MOV     r5, r24
            MOV     r4, r22
            JAL     r16, puts
            ADDI    r18, r18, 1
            ADDI    r19, r19, 1
            JMP     si_line
si_done:
            JAL     r16, wait_back
            JMP     main_loop

; ---- palette ---------------------------------------------------------------
screen_palette:
            LA      r4, s_palette
            JAL     r16, screen_frame

            ADDI    r1, r0, 6
            ADDI    r2, r0, 8
            MOV     r5, r26
            LA      r4, s_pal_h1
            JAL     r16, puts

            ZERO    r18                 ; palette index
pal_row:
            ADDI    r6, r0, 16
            CMP     r18, r6
            BGE     pal_done

            ; index label, two hex digits
            ADDI    r1, r0, 8
            ADDI    r2, r0, 10
            ADD     r2, r2, r18
            MOV     r3, r18
            MOV     r5, r27
            JAL     r16, puthex2

            ; swatch: a run of full blocks drawn in the palette colour
            ADDI    r6, r0, 8
            LSL     r5, r18, r6         ; fg = index
            ADDI    r3, r0, 0xDB
            OR      r3, r3, r5
            ADDI    r1, r0, 12
            ADDI    r2, r0, 10
            ADD     r2, r2, r18
            ADDI    r4, r0, 24
            JAL     r16, fill

            ADDI    r18, r18, 1
            JMP     pal_row
pal_done:
            JAL     r16, wait_back
            JMP     main_loop

; ---- font chart ------------------------------------------------------------
screen_font:
            LA      r4, s_font
            JAL     r16, screen_frame

            ADDI    r1, r0, 6
            ADDI    r2, r0, 8
            MOV     r5, r26
            LA      r4, s_font_h1
            JAL     r16, puts

            ZERO    r18                 ; glyph code
font_cell:
            ADDI    r6, r0, 256
            CMP     r18, r6
            BGE     font_done

            ADDI    r14, r0, 4
            LSR     r7, r18, r14        ; row  = code >> 4
            LSL     r22, r7, r14
            SUB     r22, r18, r22       ; col  = code & 15

            ADDI    r1, r0, 24
            ADD     r1, r1, r22
            ADD     r1, r1, r22         ; x = 24 + col*2
            ADDI    r2, r0, 10
            ADD     r2, r2, r7          ; y = 10 + row

            MOV     r3, r18
            OR      r3, r3, r24
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            SW      r3, r11, 0

            ADDI    r18, r18, 1
            JMP     font_cell
font_done:
            JAL     r16, wait_back
            JMP     main_loop

; ---- keypad test -----------------------------------------------------------
screen_keypad:
            LA      r4, s_keypad
            JAL     r16, screen_frame

            ADDI    r1, r0, 6
            ADDI    r2, r0, 8
            MOV     r5, r26
            LA      r4, s_kp_h1
            JAL     r16, puts

            ADDI    r1, r0, 8
            ADDI    r2, r0, 11
            MOV     r5, r24
            LA      r4, s_kp_glyph
            JAL     r16, puts

            ADDI    r1, r0, 8
            ADDI    r2, r0, 13
            MOV     r5, r24
            LA      r4, s_kp_code
            JAL     r16, puts

kp_wait:
            JAL     r16, getkey
            MOV     r21, r1

            ; the keycode is its own glyph — draw it big and plain
            ADDI    r1, r0, 24
            ADDI    r2, r0, 11
            MOV     r3, r21
            OR      r3, r3, r26
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            SW      r3, r11, 0

            ADDI    r1, r0, 24
            ADDI    r2, r0, 13
            MOV     r3, r21
            MOV     r5, r24
            JAL     r16, puthex2

            ADDI    r6, r0, 0x11        ; left = back
            CMP     r21, r6
            BEQ     kp_done
            JMP     kp_wait
kp_done:
            JMP     main_loop

; ---- about -----------------------------------------------------------------
screen_about:
            LA      r4, s_about
            JAL     r16, screen_frame

            ADDI    r1, r0, 6
            ADDI    r2, r0, 8
            MOV     r5, r26
            LA      r4, s_owner
            JAL     r16, puts

            LA      r19, ab_body
            ADDI    r18, r0, 10
ab_line:
            LW      r22, r19, 0
            CMP     r22, r0
            BEQ     ab_done
            ADDI    r1, r0, 8
            MOV     r2, r18
            MOV     r5, r24
            MOV     r4, r22
            JAL     r16, puts
            ADDI    r18, r18, 1
            ADDI    r19, r19, 1
            JMP     ab_line
ab_done:
            ADDI    r1, r0, 8
            ADDI    r2, r0, 22
            ADDI    r3, r0, 56
            ADDI    r4, r0, 7
            MOV     r5, r26
            JAL     r16, box

            ADDI    r1, r0, 12
            ADDI    r2, r0, 24
            MOV     r5, r26
            LA      r4, c_2
            JAL     r16, puts
            ADDI    r1, r0, 12
            ADDI    r2, r0, 25
            MOV     r5, r24
            LA      r4, c_3
            JAL     r16, puts
            ADDI    r1, r0, 12
            ADDI    r2, r0, 26
            MOV     r5, r27
            LA      r4, s_penn
            JAL     r16, puts

            JAL     r16, wait_back
            JMP     main_loop

; ---- memory map ------------------------------------------------------------
screen_map:
            LA      r4, s_map
            JAL     r16, screen_frame

            ADDI    r1, r0, 6
            ADDI    r2, r0, 8
            MOV     r5, r26
            LA      r4, s_map_h1
            JAL     r16, puts

            LA      r19, map_body
            ADDI    r18, r0, 10
map_line:
            LW      r22, r19, 0
            CMP     r22, r0
            BEQ     map_done
            ADDI    r1, r0, 8
            MOV     r2, r18
            MOV     r5, r24
            MOV     r4, r22
            JAL     r16, puts
            ADDI    r18, r18, 1
            ADDI    r19, r19, 1
            JMP     map_line
map_done:
            JAL     r16, wait_back
            JMP     main_loop

; ============================================================================
; Fibonacci — r18 is the selected n, and the whole table is recomputed on
; every keystroke because at 46 terms that costs less than storing it.
; ============================================================================
screen_fib:
            LA      r4, s_fib
            JAL     r16, screen_frame
            LA      r4, s_fib_keys
            JAL     r16, footer

            ADDI    r18, r0, 10
fib_loop:
            JAL     r16, fib_draw
fib_key:
            JAL     r16, getkey
            MOV     r21, r1

            ADDI    r6, r0, 0x11        ; left — back to the menu
            CMP     r21, r6
            BEQ     fib_quit
            ADDI    r6, r0, 0x1E        ; up — next term
            CMP     r21, r6
            BEQ     fib_up
            ADDI    r6, r0, 0x1F        ; down — previous term
            CMP     r21, r6
            BEQ     fib_down
            ADDI    r6, r0, 0x10        ; right — jump ten
            CMP     r21, r6
            BEQ     fib_fwd
            ADDI    r6, r0, 0x0D        ; enter — replay from zero
            CMP     r21, r6
            BEQ     fib_anim
            JMP     fib_key

fib_up:
            ADDI    r6, r0, 46          ; F(46) is the last term under 2^31
            CMP     r18, r6
            BGE     fib_loop
            ADDI    r18, r18, 1
            JMP     fib_loop
fib_down:
            CMP     r18, r0
            BEQ     fib_loop
            ADDI    r18, r18, -1
            JMP     fib_loop
fib_fwd:
            ADDI    r18, r18, 10
            ADDI    r6, r0, 46
            CMP     r18, r6
            BLT     fib_loop
            MOV     r18, r6
            JMP     fib_loop

; Walk n from 0 back up to where it was, one term per tick, so the growth is
; something you watch rather than read.
fib_anim:
            MOV     r19, r18
            ZERO    r18
fib_an_l:
            JAL     r16, fib_draw
            LA      r11, tune_fib
            LW      r3, r11, 0
            JAL     r16, gwait
            CMP     r18, r19
            BGE     fib_loop
            ADDI    r18, r18, 1
            JMP     fib_an_l

fib_quit:
            JMP     main_loop

; fib_draw: headline plus a 24-slot window around n, with n picked out in gold.
fib_draw:
            MOV     r17, r16

            ADDI    r1, r0, 6           ; n = <term>
            ADDI    r2, r0, 9
            MOV     r3, r24
            ADDI    r4, r0, 60
            JAL     r16, fill
            ADDI    r1, r0, 6
            ADDI    r2, r0, 9
            MOV     r5, r26
            LA      r4, s_fib_n
            JAL     r16, puts
            ADDI    r1, r0, 10
            ADDI    r2, r0, 9
            MOV     r3, r18
            MOV     r5, r24
            JAL     r16, putdec

            ADDI    r1, r0, 6           ; F(n) = <value>
            ADDI    r2, r0, 11
            MOV     r3, r24
            ADDI    r4, r0, 60
            JAL     r16, fill
            ADDI    r1, r0, 6
            ADDI    r2, r0, 11
            MOV     r5, r26
            LA      r4, s_fib_v
            JAL     r16, puts
            MOV     r3, r18
            JAL     r16, fib_of
            MOV     r3, r1
            ADDI    r1, r0, 13
            ADDI    r2, r0, 11
            MOV     r5, r27
            JAL     r16, putdec

            ADDI    r11, r0, 24         ; window base = floor(n/24)*24
            DIVU    r29, r18, r11
            MUL     r29, r29, r11
            ZERO    r30                 ; slot 0..23
fd_l:
            ADDI    r11, r0, 24
            CMP     r30, r11
            BGE     fd_done
            ADD     r31, r29, r30       ; the term this slot shows

            MOV     r3, r31
            JAL     r16, fib_of
            MOV     r28, r1             ; F(k) — putdec would eat r1

            JAL     r16, fd_xy
            MOV     r3, r24
            ADDI    r4, r0, 26
            JAL     r16, fill

            JAL     r16, fd_xy
            MOV     r3, r31
            MOV     r5, r27
            JAL     r16, putdec         ; the index

            ADDI    r1, r1, 4
            MOV     r5, r24
            CMP     r31, r18
            BNE     fd_plain
            MOV     r5, r26
fd_plain:
            MOV     r3, r28
            JAL     r16, putdec         ; the value

            ADDI    r30, r30, 1
            JMP     fd_l
fd_done:
            MOV     r16, r17
            JR      r16

; fd_xy: slot r30 → (r1, r2). Twelve to a column, two columns.
fd_xy:
            ADDI    r11, r0, 12
            CMP     r30, r11
            BGE     fd_xy_right
            ADDI    r1, r0, 8
            ADDI    r2, r30, 14
            JR      r16
fd_xy_right:
            ADDI    r1, r0, 42
            SUB     r2, r30, r11
            ADDI    r2, r2, 14
            JR      r16

; fib_of: F(r3) → r1. Iterative, so F(46) costs 46 adds and never recurses.
fib_of:
            ZERO    r1                  ; a = F(0)
            ADDI    r11, r0, 1          ; b = F(1)
            MOV     r12, r3
fo_l:
            CMP     r12, r0
            BEQ     fo_done
            ADD     r13, r1, r11
            MOV     r1, r11
            MOV     r11, r13
            ADDI    r12, r12, -1
            JMP     fo_l
fo_done:
            JR      r16

; ============================================================================
; Snake — the body is a ring of packed cells, so a step is one write at the
; head and one erase at the tail rather than a redraw of the field.
;   cell = y*64 + x, 40 wide by 20 tall, drawn from (20, 14)
;   r6,r7 direction   r18 head index   r19 tail index
;   r21 length        r22 food cell    r28 score
; ============================================================================
screen_snake:
snake_new:
            LA      r4, s_snake
            JAL     r16, screen_frame
            LA      r4, s_sn_keys
            JAL     r16, footer

            ADDI    r1, r0, 19          ; playfield rule
            ADDI    r2, r0, 13
            ADDI    r3, r0, 42
            ADDI    r4, r0, 22
            MOV     r5, r27
            JAL     r16, box

            ZERO    r18
sn_clr:
            ADDI    r6, r0, 20
            CMP     r18, r6
            BGE     sn_clr_done
            ADDI    r1, r0, 20
            ADDI    r2, r0, 14
            ADD     r2, r2, r18
            ZERO    r3
            ADDI    r4, r0, 40
            JAL     r16, fill
            ADDI    r18, r18, 1
            JMP     sn_clr
sn_clr_done:

            ADDI    r1, r0, 24          ; "press a key to start"
            ADDI    r2, r0, 23
            MOV     r5, r26
            LA      r4, s_start
            JAL     r16, puts
            JAL     r16, seed_wait
            ADDI    r1, r0, 24
            ADDI    r2, r0, 23
            MOV     r3, r0
            ADDI    r4, r0, 32
            JAL     r16, fill

            ; three cells long, heading right out of the middle
            LA      r30, sn_buf
            ZERO    r29
sn_init:
            ADDI    r6, r0, 3
            CMP     r29, r6
            BGE     sn_init_done
            ADDI    r31, r0, 658        ; 10*64 + 18
            ADD     r31, r31, r29
            ADD     r11, r30, r29
            SW      r31, r11, 0
            MOV     r3, r31
            ADDI    r4, r0, 0x0ADB
            JAL     r16, sn_put
            ADDI    r29, r29, 1
            JMP     sn_init
sn_init_done:
            ADDI    r3, r0, 660         ; the head wears a different colour
            ADDI    r4, r0, 0x0EDB
            JAL     r16, sn_put

            ADDI    r6, r0, 1           ; dx
            ZERO    r7                  ; dy
            ADDI    r21, r0, 3          ; length
            ZERO    r19                 ; tail index
            ADDI    r18, r0, 2          ; head index
            ZERO    r28                 ; score
            JAL     r16, sn_score
            JAL     r16, sn_food

; A step is eight slices. Input is answered inside a slice, so the snake turns
; the moment you press even though it only advances once per eight.
sn_play:
            ZERO    r29
sn_slice:
            LA      r11, tune_snake
            LW      r3, r11, 0
            JAL     r16, gwait
            MOV     r31, r1
            CMP     r31, r0
            BEQ     sn_slice_end

            ADDI    r11, r0, 0x0D
            CMP     r31, r11
            BEQ     sn_quit

            ADDI    r11, r0, 0x1E       ; up
            CMP     r31, r11
            BNE     sn_k_down
            CMP     r7, r0              ; already vertical: ignore, no reversal
            BNE     sn_slice_end
            ZERO    r6
            ADDI    r7, r0, -1
            JMP     sn_slice_end
sn_k_down:
            ADDI    r11, r0, 0x1F
            CMP     r31, r11
            BNE     sn_k_left
            CMP     r7, r0
            BNE     sn_slice_end
            ZERO    r6
            ADDI    r7, r0, 1
            JMP     sn_slice_end
sn_k_left:
            ADDI    r11, r0, 0x11
            CMP     r31, r11
            BNE     sn_k_right
            CMP     r6, r0
            BNE     sn_slice_end
            ADDI    r6, r0, -1
            ZERO    r7
            JMP     sn_slice_end
sn_k_right:
            ADDI    r11, r0, 0x10
            CMP     r31, r11
            BNE     sn_slice_end
            CMP     r6, r0
            BNE     sn_slice_end
            ADDI    r6, r0, 1
            ZERO    r7
sn_slice_end:
            ADDI    r29, r29, 1
            ADDI    r11, r0, 8
            CMP     r29, r11
            BLT     sn_slice

            ; ---- advance one cell ----
            LA      r11, sn_buf
            ADD     r11, r11, r18
            LW      r31, r11, 0         ; the cell the head is leaving
            ADDI    r11, r0, 6
            LSR     r12, r31, r11       ; y
            LSL     r13, r12, r11
            SUB     r13, r31, r13       ; x
            ADD     r13, r13, r6
            ADD     r12, r12, r7

            CMP     r13, r0             ; walls are fatal
            BLT     sn_dead
            ADDI    r11, r0, 40
            CMP     r13, r11
            BGE     sn_dead
            CMP     r12, r0
            BLT     sn_dead
            ADDI    r11, r0, 20
            CMP     r12, r11
            BGE     sn_dead

            ADDI    r11, r0, 6
            LSL     r30, r12, r11
            ADD     r30, r30, r13       ; the cell the head is entering

            ZERO    r29                 ; does this step eat?
            CMP     r30, r22
            BNE     sn_grow_no
            ADDI    r29, r0, 1
sn_grow_no:
            ; The tail square is only fatal when the tail is staying put, which
            ; is exactly when this step grows.
            CMP     r29, r0
            BEQ     sn_scan_skip
            ZERO    r11
            JMP     sn_scan
sn_scan_skip:
            ADDI    r11, r0, 1
sn_scan:
            CMP     r11, r21
            BGE     sn_move
            ADD     r12, r19, r11
            ADDI    r13, r0, 127
            AND     r12, r12, r13
            LA      r13, sn_buf
            ADD     r12, r12, r13
            LW      r12, r12, 0
            CMP     r12, r30
            BEQ     sn_dead
            ADDI    r11, r11, 1
            JMP     sn_scan

sn_move:
            MOV     r3, r31             ; old head becomes body
            ADDI    r4, r0, 0x0ADB
            JAL     r16, sn_put

            ADDI    r18, r18, 1
            ADDI    r11, r0, 127
            AND     r18, r18, r11
            LA      r11, sn_buf
            ADD     r11, r11, r18
            SW      r30, r11, 0
            MOV     r3, r30
            ADDI    r4, r0, 0x0EDB
            JAL     r16, sn_put

            CMP     r29, r0
            BEQ     sn_shrink
            ADDI    r21, r21, 1
            ADDI    r28, r28, 1
            JAL     r16, sn_score
            ADDI    r11, r0, 118        ; the ring is 128 — stop short of it
            CMP     r21, r11
            BGE     sn_win
            JAL     r16, sn_food
            JMP     sn_play
sn_shrink:
            LA      r11, sn_buf
            ADD     r11, r11, r19
            LW      r12, r11, 0
            MOV     r3, r12
            ZERO    r4
            JAL     r16, sn_put
            ADDI    r19, r19, 1
            ADDI    r11, r0, 127
            AND     r19, r19, r11
            JMP     sn_play

sn_dead:
            LA      r4, s_sn_over
            JAL     r16, game_over
            CMP     r1, r0
            BEQ     sn_quit
            JMP     snake_new
sn_win:
            LA      r4, s_sn_win
            JAL     r16, game_over
            CMP     r1, r0
            BEQ     sn_quit
            JMP     snake_new
sn_quit:
            JMP     main_loop

; sn_put: paint packed cell r3 with tile word r4.
sn_put:
            ADDI    r11, r0, 6
            LSR     r12, r3, r11
            LSL     r13, r12, r11
            SUB     r13, r3, r13
            ADDI    r12, r12, 14
            ADDI    r13, r13, 20
            MUL     r14, r12, r10
            ADD     r14, r14, r13
            ADD     r14, r14, r8
            SW      r4, r14, 0
            JR      r16

; sn_food: drop a pellet on a free cell, remember it in r22, and paint it.
sn_food:
            MOV     r17, r16
sf_try:
            JAL     r16, rnd
            ADDI    r12, r0, 40
            REMU    r13, r1, r12
            ADDI    r12, r0, 6
            LSR     r14, r1, r12
            ADDI    r12, r0, 20
            REMU    r14, r14, r12
            ADDI    r12, r0, 6
            LSL     r22, r14, r12
            ADD     r22, r22, r13
            ZERO    r11
sf_scan:
            CMP     r11, r21
            BGE     sf_ok
            ADD     r12, r19, r11
            ADDI    r13, r0, 127
            AND     r12, r12, r13
            LA      r13, sn_buf
            ADD     r12, r12, r13
            LW      r12, r12, 0
            CMP     r12, r22
            BEQ     sf_try
            ADDI    r11, r11, 1
            JMP     sf_scan
sf_ok:
            MOV     r3, r22
            ADDI    r4, r0, 0x0C07
            JAL     r16, sn_put
            MOV     r16, r17
            JR      r16

; sn_score: the tally, off to the right of the playfield.
sn_score:
            MOV     r17, r16
            ADDI    r1, r0, 63
            ADDI    r2, r0, 14
            MOV     r5, r26
            LA      r4, s_sn_score
            JAL     r16, puts
            ADDI    r1, r0, 63
            ADDI    r2, r0, 16
            MOV     r3, r24
            ADDI    r4, r0, 10
            JAL     r16, fill
            ADDI    r1, r0, 63
            ADDI    r2, r0, 16
            MOV     r3, r28
            MOV     r5, r24
            JAL     r16, putdec
            MOV     r16, r17
            JR      r16

; ============================================================================
; Tetris — the board is twenty 10-bit row masks, so a collision test is an AND
; and a completed line is a compare against 0x3FF.
;   r6,r7 piece x/y   r18 kind   r19 rotation   r21 lines   r22 slice
;   cells are two characters wide, drawn from (30, 16)
; ============================================================================
screen_tetris:
tetris_new:
            LA      r4, s_tetris
            JAL     r16, screen_frame
            LA      r4, s_tt_keys
            JAL     r16, footer

            ADDI    r1, r0, 29
            ADDI    r2, r0, 15
            ADDI    r3, r0, 22
            ADDI    r4, r0, 22
            MOV     r5, r27
            JAL     r16, box

            LA      r11, tt_row         ; empty board
            ZERO    r12
tt_zero:
            ADDI    r13, r0, 20
            CMP     r12, r13
            BGE     tt_zero_done
            ADD     r14, r11, r12
            SW      r0, r14, 0
            ADDI    r12, r12, 1
            JMP     tt_zero
tt_zero_done:
            ZERO    r21
            JAL     r16, tt_lines

            ADDI    r1, r0, 33
            ADDI    r2, r0, 25
            MOV     r5, r26
            LA      r4, s_start
            JAL     r16, puts
            JAL     r16, seed_wait

            JAL     r16, tt_spawn
            CMP     r5, r0
            BNE     tt_dead
            JAL     r16, tt_draw

tt_play:
            ZERO    r22
tt_slice:
            LA      r11, tune_tetris
            LW      r3, r11, 0
            JAL     r16, gwait
            MOV     r28, r1
            CMP     r28, r0
            BEQ     tt_slice_end

            ADDI    r11, r0, 0x0D
            CMP     r28, r11
            BEQ     tt_quit

            ADDI    r11, r0, 0x11       ; left
            CMP     r28, r11
            BNE     tt_k_right
            ADDI    r29, r6, -1
            MOV     r1, r18
            MOV     r2, r19
            MOV     r3, r29
            MOV     r4, r7
            JAL     r16, tt_hit
            CMP     r5, r0
            BNE     tt_slice_end
            ADDI    r6, r6, -1
            JAL     r16, tt_draw
            JMP     tt_slice_end
tt_k_right:
            ADDI    r11, r0, 0x10       ; right
            CMP     r28, r11
            BNE     tt_k_rot
            ADDI    r29, r6, 1
            MOV     r1, r18
            MOV     r2, r19
            MOV     r3, r29
            MOV     r4, r7
            JAL     r16, tt_hit
            CMP     r5, r0
            BNE     tt_slice_end
            ADDI    r6, r6, 1
            JAL     r16, tt_draw
            JMP     tt_slice_end
tt_k_rot:
            ADDI    r11, r0, 0x1E       ; up rotates
            CMP     r28, r11
            BNE     tt_k_drop
            ADDI    r29, r19, 1
            ADDI    r11, r0, 3
            AND     r29, r29, r11
            MOV     r1, r18
            MOV     r2, r29
            MOV     r3, r6
            MOV     r4, r7
            JAL     r16, tt_hit
            CMP     r5, r0
            BNE     tt_slice_end
            MOV     r19, r29
            JAL     r16, tt_draw
            JMP     tt_slice_end
tt_k_drop:
            ADDI    r11, r0, 0x1F       ; down drops a row now
            CMP     r28, r11
            BNE     tt_slice_end
            JMP     tt_step
tt_slice_end:
            ADDI    r22, r22, 1
            ADDI    r11, r0, 8
            CMP     r22, r11
            BLT     tt_slice

tt_step:
            ADDI    r29, r7, 1
            MOV     r1, r18
            MOV     r2, r19
            MOV     r3, r6
            MOV     r4, r29
            JAL     r16, tt_hit
            CMP     r5, r0
            BNE     tt_landed
            ADDI    r7, r7, 1
            JAL     r16, tt_draw
            JMP     tt_play
tt_landed:
            JAL     r16, tt_lock
            JAL     r16, tt_clear
            JAL     r16, tt_lines
            JAL     r16, tt_spawn
            CMP     r5, r0
            BNE     tt_dead
            JAL     r16, tt_draw
            JMP     tt_play

tt_dead:
            LA      r4, s_tt_over
            JAL     r16, game_over
            CMP     r1, r0
            BEQ     tt_quit
            JMP     tetris_new
tt_quit:
            JMP     main_loop

; tt_cell: board cell (r1 col, r2 row) painted with tile r3, two glyphs wide.
tt_cell:
            ADDI    r11, r2, 16
            MUL     r11, r11, r10
            ADD     r12, r1, r1
            ADDI    r12, r12, 30
            ADD     r11, r11, r12
            ADD     r11, r11, r8
            SW      r3, r11, 0
            SW      r3, r11, 1
            JR      r16

; tt_hit: would piece (r1 kind, r2 rotation) sit at (r3, r4) illegally?
;   r5 = 1 blocked, 0 clear. Cells above the board are allowed, which is what
;   lets a piece spawn straddling the ceiling.
tt_hit:
            ADDI    r11, r0, 4
            MUL     r11, r1, r11
            ADD     r11, r11, r2
            LA      r12, tt_shapes
            ADD     r12, r12, r11
            LW      r13, r12, 0         ; shape, consumed one bit at a time
            ZERO    r5
            ADDI    r14, r0, 15         ; cell index, 0 is top-left
th_l:
            ADDI    r15, r0, 1
            AND     r15, r13, r15
            CMP     r15, r0
            BEQ     th_next
            ADDI    r15, r0, 2
            LSR     r15, r14, r15       ; row inside the 4x4
            ADD     r12, r4, r15        ; board Y
            ADDI    r11, r0, 2
            LSL     r11, r15, r11
            SUB     r11, r14, r11       ; column inside the 4x4
            ADD     r11, r3, r11        ; board X

            CMP     r11, r0
            BLT     th_hit
            ADDI    r15, r0, 10
            CMP     r11, r15
            BGE     th_hit
            ADDI    r15, r0, 20
            CMP     r12, r15
            BGE     th_hit
            CMP     r12, r0
            BLT     th_next

            LA      r15, tt_row
            ADD     r15, r15, r12
            LW      r15, r15, 0
            ADDI    r12, r0, 1
            LSL     r12, r12, r11
            AND     r15, r15, r12
            CMP     r15, r0
            BNE     th_hit
th_next:
            ADDI    r15, r0, 1
            LSR     r13, r13, r15
            ADDI    r14, r14, -1
            CMP     r14, r0
            BGE     th_l
            JR      r16
th_hit:
            ADDI    r5, r0, 1
            JR      r16

; tt_lock: stamp the live piece into the row masks.
tt_lock:
            ADDI    r11, r0, 4
            MUL     r11, r18, r11
            ADD     r11, r11, r19
            LA      r12, tt_shapes
            ADD     r12, r12, r11
            LW      r13, r12, 0
            ADDI    r14, r0, 15
tl_l:
            ADDI    r15, r0, 1
            AND     r15, r13, r15
            CMP     r15, r0
            BEQ     tl_next
            ADDI    r15, r0, 2
            LSR     r11, r14, r15
            LSL     r12, r11, r15
            SUB     r12, r14, r12
            ADD     r11, r11, r7        ; Y
            ADD     r12, r12, r6        ; X
            CMP     r11, r0
            BLT     tl_next
            LA      r15, tt_row
            ADD     r15, r15, r11
            LW      r11, r15, 0
            ADDI    r5, r0, 1
            LSL     r5, r5, r12
            OR      r11, r11, r5
            SW      r11, r15, 0
tl_next:
            ADDI    r15, r0, 1
            LSR     r13, r13, r15
            ADDI    r14, r14, -1
            CMP     r14, r0
            BGE     tl_l
            JR      r16

; tt_clear: drop out every full row, counting them into r21. A cleared row is
; re-tested rather than skipped, so a stack of them collapses in one pass.
tt_clear:
            ADDI    r14, r0, 19
tc_l:
            CMP     r14, r0
            BLT     tc_done
            LA      r11, tt_row
            ADD     r11, r11, r14
            LW      r12, r11, 0
            ADDI    r13, r0, 1023
            CMP     r12, r13
            BNE     tc_up
            MOV     r15, r14
tc_sh:
            CMP     r15, r0
            BEQ     tc_top
            LA      r11, tt_row
            ADD     r11, r11, r15
            ADDI    r12, r11, -1
            LW      r13, r12, 0
            SW      r13, r11, 0
            ADDI    r15, r15, -1
            JMP     tc_sh
tc_top:
            LA      r11, tt_row
            SW      r0, r11, 0
            ADDI    r21, r21, 1
            JMP     tc_l
tc_up:
            ADDI    r14, r14, -1
            JMP     tc_l
tc_done:
            JR      r16

; tt_spawn: a fresh piece straddling the ceiling. r5 = 1 if it does not fit.
tt_spawn:
            MOV     r17, r16
            JAL     r16, rnd
            ADDI    r12, r0, 7
            REMU    r18, r1, r12
            ZERO    r19
            ADDI    r6, r0, 3
            ADDI    r7, r0, -1
            MOV     r1, r18
            MOV     r2, r19
            MOV     r3, r6
            MOV     r4, r7
            JAL     r16, tt_hit
            MOV     r16, r17
            JR      r16

; tt_draw: the settled board, then the live piece over it. Two hundred cells
; is well inside one tick even at 6.25 MHz, so there is no dirty-cell logic.
tt_draw:
            MOV     r17, r16
            ZERO    r29
tdr_row:
            ADDI    r11, r0, 20
            CMP     r29, r11
            BGE     tdr_piece
            LA      r11, tt_row
            ADD     r11, r11, r29
            LW      r30, r11, 0
            ZERO    r31
tdr_col:
            ADDI    r11, r0, 10
            CMP     r31, r11
            BGE     tdr_col_done
            ADDI    r11, r0, 1
            LSL     r11, r11, r31
            AND     r11, r30, r11
            CMP     r11, r0
            BEQ     tdr_empty
            ADDI    r3, r0, 0x07DB
            JMP     tdr_paint
tdr_empty:
            ADDI    r3, r0, 0x08B0
tdr_paint:
            MOV     r1, r31
            MOV     r2, r29
            JAL     r16, tt_cell
            ADDI    r31, r31, 1
            JMP     tdr_col
tdr_col_done:
            ADDI    r29, r29, 1
            JMP     tdr_row
tdr_piece:
            ADDI    r11, r0, 4
            MUL     r11, r18, r11
            ADD     r11, r11, r19
            LA      r12, tt_shapes
            ADD     r12, r12, r11
            LW      r30, r12, 0
            LA      r12, tt_colour
            ADD     r12, r12, r18
            LW      r29, r12, 0
            ADDI    r31, r0, 15
tdp_l:
            ADDI    r11, r0, 1
            AND     r11, r30, r11
            CMP     r11, r0
            BEQ     tdp_next
            ADDI    r11, r0, 2
            LSR     r12, r31, r11
            LSL     r13, r12, r11
            SUB     r13, r31, r13
            ADD     r12, r12, r7        ; Y
            ADD     r13, r13, r6        ; X
            CMP     r12, r0
            BLT     tdp_next
            ADDI    r11, r0, 20
            CMP     r12, r11
            BGE     tdp_next
            MOV     r1, r13
            MOV     r2, r12
            MOV     r3, r29
            JAL     r16, tt_cell
tdp_next:
            ADDI    r11, r0, 1
            LSR     r30, r30, r11
            ADDI    r31, r31, -1
            CMP     r31, r0
            BGE     tdp_l
            MOV     r16, r17
            JR      r16

; tt_lines: the counter beside the well.
tt_lines:
            MOV     r17, r16
            ADDI    r1, r0, 54
            ADDI    r2, r0, 16
            MOV     r5, r26
            LA      r4, s_tt_lines
            JAL     r16, puts
            ADDI    r1, r0, 54
            ADDI    r2, r0, 18
            MOV     r3, r24
            ADDI    r4, r0, 10
            JAL     r16, fill
            ADDI    r1, r0, 54
            ADDI    r2, r0, 18
            MOV     r3, r21
            MOV     r5, r24
            JAL     r16, putdec
            MOV     r16, r17
            JR      r16

; ============================================================================
; Composites — these call leaves, so they park the link in r17 themselves
; ============================================================================

; splash: tomato field, name, a bar that fills, then the desktop takes over.
; tune_boot at 0xE03 is the wait per step; benches poke it to 1.
splash:
            MOV     r17, r16

            MOV     r3, r25
            JAL     r16, cls

            ADDI    r6, r0, 8
            ADDI    r3, r0, 0x4E
            LSL     r3, r3, r6
            ADDI    r3, r3, 0xDB        ; gold blocks on tomato

            ADDI    r1, r0, 34
            ADDI    r2, r0, 16
            ADDI    r4, r0, 12
            JAL     r16, fill
            ADDI    r1, r0, 32
            ADDI    r2, r0, 17
            ADDI    r4, r0, 16
            JAL     r16, fill
            ADDI    r1, r0, 34
            ADDI    r2, r0, 18
            ADDI    r4, r0, 12
            JAL     r16, fill

            ADDI    r1, r0, 35
            ADDI    r2, r0, 21
            MOV     r5, r25
            LA      r4, s_sp_name
            JAL     r16, puts
            ADDI    r1, r0, 38
            ADDI    r2, r0, 23
            MOV     r5, r25
            LA      r4, s_sp_tag
            JAL     r16, puts
            ADDI    r1, r0, 27
            ADDI    r2, r0, 25
            MOV     r5, r25
            LA      r4, s_owner
            JAL     r16, puts
            ADDI    r1, r0, 28
            ADDI    r2, r0, 29
            MOV     r5, r25
            LA      r4, s_sp_ld
            JAL     r16, puts

            ADDI    r1, r0, 20
            ADDI    r2, r0, 32
            ADDI    r6, r0, 8
            ADDI    r3, r0, 0x47
            LSL     r3, r3, r6
            ADDI    r3, r3, 0xC4        ; dim track
            ADDI    r4, r0, 40
            JAL     r16, fill

            ZERO    r18
sp_bar:
            ADDI    r6, r0, 20
            CMP     r18, r6
            BGE     sp_done

            ADDI    r6, r0, 8
            ADDI    r3, r0, 0x4F
            LSL     r3, r3, r6
            ADDI    r3, r3, 0xDB
            ADDI    r1, r0, 20
            ADDI    r2, r0, 32
            ADD     r4, r18, r18        ; two cells per step
            JAL     r16, fill

            LA      r11, tune_boot
            LW      r3, r11, 0
            JAL     r16, gwait

            ADDI    r18, r18, 1
            JMP     sp_bar
sp_done:
            MOV     r16, r17
            JR      r16

; draw_desktop: clear, title bar, owner, footer, menu frame, machine card.
draw_desktop:
            MOV     r17, r16

            ZERO    r3
            JAL     r16, cls

            ADDI    r1, r0, 0           ; title bar across the top
            ADDI    r2, r0, 0
            MOV     r3, r25
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 0
            MOV     r5, r25
            LA      r4, s_title
            JAL     r16, puts
            ADDI    r1, r0, 54
            ADDI    r2, r0, 0
            MOV     r5, r25
            LA      r4, s_owner
            JAL     r16, puts

            ADDI    r1, r0, 0           ; second bar: the claim
            ADDI    r2, r0, 1
            MOV     r3, r27
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 1
            MOV     r5, r27
            LA      r4, s_claim
            JAL     r16, puts
            ADDI    r1, r0, 68
            ADDI    r2, r0, 1
            MOV     r5, r27
            LA      r4, s_ready
            JAL     r16, puts

            ADDI    r1, r0, 0           ; footer bar across the bottom
            ADDI    r2, r0, 59
            MOV     r3, r23
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 59
            MOV     r5, r23
            LA      r4, s_keys
            JAL     r16, puts

            ADDI    r1, r0, 4           ; menu frame — nine entries
            ADDI    r2, r0, 3
            ADDI    r3, r0, 34
            ADDI    r4, r0, 12
            MOV     r5, r27
            JAL     r16, box
            ADDI    r1, r0, 6
            ADDI    r2, r0, 3
            MOV     r5, r26
            LA      r4, s_menu_hd
            JAL     r16, puts

            ADDI    r1, r0, 40          ; the machine card
            ADDI    r2, r0, 3
            ADDI    r3, r0, 36
            ADDI    r4, r0, 12
            MOV     r5, r27
            JAL     r16, box
            ADDI    r1, r0, 42
            ADDI    r2, r0, 3
            MOV     r5, r26
            LA      r4, s_card_hd
            JAL     r16, puts

            LA      r19, card_body
            ADDI    r18, r0, 5
dd_card:
            LW      r22, r19, 0
            CMP     r22, r0
            BEQ     dd_card_done
            ADDI    r1, r0, 42
            MOV     r2, r18
            MOV     r5, r24
            MOV     r4, r22
            JAL     r16, puts
            ADDI    r18, r18, 1
            ADDI    r19, r19, 1
            JMP     dd_card
dd_card_done:
            ADDI    r1, r0, 42
            ADDI    r2, r0, 6
            MOV     r5, r26
            LA      r4, c_2
            JAL     r16, puts

            MOV     r16, r17
            JR      r16

; screen_frame: desktop chrome with a full-width panel. r4 = title string.
screen_frame:
            MOV     r17, r16
            MOV     r22, r4             ; keep the caption across the calls

            ZERO    r3
            JAL     r16, cls

            ADDI    r1, r0, 0
            ADDI    r2, r0, 0
            MOV     r3, r25
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 0
            MOV     r5, r25
            LA      r4, s_title
            JAL     r16, puts
            ADDI    r1, r0, 54
            ADDI    r2, r0, 0
            MOV     r5, r25
            LA      r4, s_owner
            JAL     r16, puts

            ADDI    r1, r0, 0
            ADDI    r2, r0, 59
            MOV     r3, r23
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 59
            MOV     r5, r23
            LA      r4, s_back
            JAL     r16, puts

            ADDI    r1, r0, 4
            ADDI    r2, r0, 6
            ADDI    r3, r0, 72
            ADDI    r4, r0, 50
            MOV     r5, r27
            JAL     r16, box

            ADDI    r1, r0, 6
            ADDI    r2, r0, 6
            MOV     r5, r26
            MOV     r4, r22
            JAL     r16, puts

            MOV     r16, r17
            JR      r16

; footer: replace the bottom bar legend with the string in r4. Games need
; different keys advertised than the screens do.
footer:
            MOV     r17, r16
            MOV     r22, r4
            ADDI    r1, r0, 0
            ADDI    r2, r0, 59
            MOV     r3, r23
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 59
            MOV     r5, r23
            MOV     r4, r22
            JAL     r16, puts
            MOV     r16, r17
            JR      r16

; draw_menu: n_menu entries inside the frame, r20 highlighted.
draw_menu:
            MOV     r17, r16
            ZERO    r18                 ; entry index
            LA      r19, menu_items
            LA      r7, n_menu
            LW      r7, r7, 0
dm_entry:
            CMP     r18, r7
            BGE     dm_done

            ADDI    r2, r0, 5
            ADD     r2, r2, r18         ; row

            ; wipe the line so the old highlight does not linger
            ADDI    r1, r0, 5
            MOV     r3, r24
            ADDI    r4, r0, 32
            JAL     r16, fill

            CMP     r18, r20
            BNE     dm_plain
            ; selected: paint the bar, then a caret
            ADDI    r1, r0, 5
            ADDI    r2, r0, 5
            ADD     r2, r2, r18
            MOV     r3, r23
            ADDI    r4, r0, 32
            JAL     r16, fill
            ADDI    r1, r0, 6
            ADDI    r2, r0, 5
            ADD     r2, r2, r18
            ADDI    r3, r0, 0x10        ; right-pointing caret
            OR      r3, r3, r23
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            SW      r3, r11, 0
            MOV     r5, r23
            JMP     dm_text
dm_plain:
            MOV     r5, r24
dm_text:
            ADDI    r1, r0, 8
            ADDI    r2, r0, 5
            ADD     r2, r2, r18
            LW      r4, r19, 0
            JAL     r16, puts

            ADDI    r18, r18, 1
            ADDI    r19, r19, 1
            JMP     dm_entry
dm_done:
            MOV     r16, r17
            JR      r16

; wait_back: spin until LEFT or ENTER. clobbers r1, r6, r11..r15
wait_back:
            MOV     r17, r16
wb_loop:
            JAL     r16, getkey
            ADDI    r6, r0, 0x11        ; left
            CMP     r1, r6
            BEQ     wb_done
            ADDI    r6, r0, 0x0D        ; enter
            CMP     r1, r6
            BEQ     wb_done
            JMP     wb_loop
wb_done:
            MOV     r16, r17
            JR      r16

; game_over: banner captioned r4, then ENTER to play again (r1 = 1) or any
; other key to leave (r1 = 0). The caption goes through memory because every
; register a game could spare is already holding something.
game_over:
            MOV     r17, r16
            LA      r11, v_capt
            SW      r4, r11, 0

            ADDI    r1, r0, 24
            ADDI    r2, r0, 26
            ADDI    r3, r0, 32
            ADDI    r4, r0, 6
            MOV     r5, r26
            JAL     r16, box

            ADDI    r18, r0, 27
go_wipe:
            ADDI    r11, r0, 31
            CMP     r18, r11
            BGE     go_text
            ADDI    r1, r0, 25
            MOV     r2, r18
            MOV     r3, r24
            ADDI    r4, r0, 30
            JAL     r16, fill
            ADDI    r18, r18, 1
            JMP     go_wipe
go_text:
            ADDI    r1, r0, 26
            ADDI    r2, r0, 28
            MOV     r5, r26
            LA      r11, v_capt
            LW      r4, r11, 0
            JAL     r16, puts
            ADDI    r1, r0, 26
            ADDI    r2, r0, 29
            MOV     r5, r24
            LA      r4, s_again
            JAL     r16, puts
go_key:
            JAL     r16, getkey
            ADDI    r11, r0, 0x0D
            CMP     r1, r11
            BEQ     go_again
            ZERO    r1
            MOV     r16, r17
            JR      r16
go_again:
            ADDI    r1, r0, 1
            MOV     r16, r17
            JR      r16

; ============================================================================
; Leaves — arguments in r1..r5, scratch r11..r15, return through r16
; ============================================================================

; cls: flood the whole 80x60 field with the tile word in r3.
cls:
            ADDI    r13, r0, 60
            MUL     r12, r13, r10       ; 4800 cells
            MOV     r11, r8
cls_l:
            CMP     r12, r0
            BEQ     cls_done
            SW      r3, r11, 0
            ADDI    r11, r11, 1
            ADDI    r12, r12, -1
            JMP     cls_l
cls_done:
            JR      r16

; fill: r4 cells of tile word r3, starting at (r1, r2).
fill:
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            MOV     r12, r4
fill_l:
            CMP     r12, r0
            BEQ     fill_done
            SW      r3, r11, 0
            ADDI    r11, r11, 1
            ADDI    r12, r12, -1
            JMP     fill_l
fill_done:
            JR      r16

; puts: NUL-terminated string at r4 to (r1, r2) with attribute r5.
puts:
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
puts_l:
            LW      r12, r4, 0
            CMP     r12, r0
            BEQ     puts_done
            OR      r13, r12, r5
            SW      r13, r11, 0
            ADDI    r11, r11, 1
            ADDI    r4, r4, 1
            JMP     puts_l
puts_done:
            JR      r16

; box: single-rule frame, r3 wide by r4 high at (r1, r2), attribute r5.
box:
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            MOV     r14, r11            ; top-left

            ADDI    r12, r0, 0xDA
            OR      r12, r12, r5
            SW      r12, r14, 0

            ADDI    r12, r0, 0xC4
            OR      r12, r12, r5
            ADDI    r13, r3, -2
            ADDI    r15, r14, 1
box_top:
            CMP     r13, r0
            BEQ     box_tr
            SW      r12, r15, 0
            ADDI    r15, r15, 1
            ADDI    r13, r13, -1
            JMP     box_top
box_tr:
            ADDI    r12, r0, 0xBF
            OR      r12, r12, r5
            SW      r12, r15, 0

            ADDI    r13, r4, -2
            MOV     r15, r14
box_side:
            CMP     r13, r0
            BEQ     box_bot
            ADD     r15, r15, r10
            ADDI    r12, r0, 0xB3
            OR      r12, r12, r5
            SW      r12, r15, 0
            ADD     r11, r15, r3
            ADDI    r11, r11, -1
            SW      r12, r11, 0
            ADDI    r13, r13, -1
            JMP     box_side
box_bot:
            ADD     r15, r15, r10
            ADDI    r12, r0, 0xC0
            OR      r12, r12, r5
            SW      r12, r15, 0
            ADDI    r12, r0, 0xC4
            OR      r12, r12, r5
            ADDI    r13, r3, -2
            ADDI    r11, r15, 1
box_bl:
            CMP     r13, r0
            BEQ     box_br
            SW      r12, r11, 0
            ADDI    r11, r11, 1
            ADDI    r13, r13, -1
            JMP     box_bl
box_br:
            ADDI    r12, r0, 0xD9
            OR      r12, r12, r5
            SW      r12, r11, 0
            JR      r16

; puthex2: byte in r3 as two hex digits at (r1, r2), attribute r5.
puthex2:
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            ADDI    r14, r0, 4

            LSR     r12, r3, r14
            ADDI    r13, r0, 10
            CMP     r12, r13
            BLT     ph_hi_dec
            ADDI    r12, r12, 55        ; 'A' - 10
            JMP     ph_hi_out
ph_hi_dec:
            ADDI    r12, r12, 48        ; '0'
ph_hi_out:
            OR      r12, r12, r5
            SW      r12, r11, 0

            LSR     r12, r3, r14
            LSL     r12, r12, r14
            SUB     r12, r3, r12
            ADDI    r13, r0, 10
            CMP     r12, r13
            BLT     ph_lo_dec
            ADDI    r12, r12, 55
            JMP     ph_lo_out
ph_lo_dec:
            ADDI    r12, r12, 48
ph_lo_out:
            OR      r12, r12, r5
            ADDI    r11, r11, 1
            SW      r12, r11, 0
            JR      r16

; putdec: unsigned r3 in decimal at (r1, r2), attribute r5. Consumes r3, leaves
; r1 and r2 alone so a caller can step across a line without recomputing them.
putdec:
            MUL     r11, r2, r10
            ADD     r11, r11, r1
            ADD     r11, r11, r8
            LA      r14, dec_buf
            ADDI    r13, r0, 10
            ZERO    r15
pd_div:
            REMU    r12, r3, r13
            ADDI    r12, r12, 48
            SW      r12, r14, 0
            ADDI    r14, r14, 1
            ADDI    r15, r15, 1
            DIVU    r3, r3, r13
            CMP     r3, r0
            BNE     pd_div
pd_emit:
            ADDI    r14, r14, -1
            LW      r12, r14, 0
            OR      r12, r12, r5
            SW      r12, r11, 0
            ADDI    r11, r11, 1
            ADDI    r15, r15, -1
            CMP     r15, r0
            BNE     pd_emit
            JR      r16

; getkey: block until a key is pending, return the code in r1.
; Reading word 0 is what drops kb_ready, so status must be read first.
getkey:
            LW      r12, r9, 1
            CMP     r12, r0
            BEQ     getkey
            LW      r1, r9, 0
            JR      r16

; gwait: burn r3 iterations while watching the keypad, so a game can hold a
; frame open and still answer the button inside it. Last code seen → r1, or 0.
gwait:
            ZERO    r1
            MOV     r13, r3
gw_l:
            CMP     r13, r0
            BEQ     gw_done
            LW      r12, r9, 1
            CMP     r12, r0
            BEQ     gw_next
            LW      r1, r9, 0
gw_next:
            ADDI    r13, r13, -1
            JMP     gw_l
gw_done:
            JR      r16

; seed_wait: block for a key, counting while it waits. There is no clock on
; this machine, so how long a person takes to press is the entropy.
seed_wait:
            LA      r14, v_seed
            LW      r15, r14, 0
sw_l:
            ADDI    r15, r15, 1
            LW      r12, r9, 1
            CMP     r12, r0
            BEQ     sw_l
            LW      r12, r9, 0
            SW      r15, r14, 0
            JR      r16

; rnd: xorshift32. Shifts of 13, 17 and 5 need no constant the ISA cannot
; build, which a multiplicative generator would.
rnd:
            LA      r13, v_seed
            LW      r12, r13, 0
            CMP     r12, r0
            BNE     rnd_go
            ADDI    r12, r0, 2463       ; a zero seed is a dead generator
rnd_go:
            ADDI    r11, r0, 13
            LSL     r14, r12, r11
            XOR     r12, r12, r14
            ADDI    r11, r0, 17
            LSR     r14, r12, r11
            XOR     r12, r12, r14
            ADDI    r11, r0, 5
            LSL     r14, r12, r11
            XOR     r12, r12, r14
            SW      r12, r13, 0
            MOV     r1, r12
            JR      r16

; ============================================================================
; Data
; ============================================================================
            .org 0x590

s_title:    .asciz "TOMATO OS  v1.0"
s_owner:    .asciz "Designed by Tyrone Marhguy"
s_claim:    .asciz "dual-LUT3 ALU  -  524288 ops  -  256 GPR 3R1W"
s_ready:    .asciz "READY"
s_keys:     .asciz "\x1e \x1f move    ENTER select    \x11 back"
s_back:     .asciz "\x11 back"
s_menu_hd:  .asciz " MAIN MENU "
s_card_hd:  .asciz " THE MACHINE "
s_start:    .asciz "press any key to start"
s_again:    .asciz "ENTER play again    \x11 menu"

s_sp_name:  .asciz "TOMATO OS"
s_sp_tag:   .asciz "v1.0"
s_sp_ld:    .asciz "bringing the machine up"

menu_items: .word m_sysinfo, m_palette, m_font, m_keypad
            .word m_fib, m_snake, m_tetris, m_about, m_map
menu_targets:
            .word screen_sysinfo, screen_palette, screen_font, screen_keypad
            .word screen_fib, screen_snake, screen_tetris, screen_about
            .word screen_map
n_menu:     .word 9

m_sysinfo:  .asciz "System info"
m_palette:  .asciz "Palette"
m_font:     .asciz "Font chart"
m_keypad:   .asciz "Keypad test"
m_fib:      .asciz "Fibonacci"
m_snake:    .asciz "Snake"
m_tetris:   .asciz "Tetris"
m_about:    .asciz "About Tomato"
m_map:      .asciz "Memory map"
s_penn:     .asciz "University of Pennsylvania"

s_map:      .asciz " MEMORY MAP "
s_map_h1:   .asciz "Every bus the CPU can name"
map_body:   .word mp_1, mp_2, mp_3, mp_4, mp_5, mp_6, 0
mp_1:       .asciz "0x000000     dmem / program, 16384 words"
mp_2:       .asciz "0x000100     ECALL trap"
mp_3:       .asciz "0x300000     80x60 framebuffer"
mp_4:       .asciz "0x780000     keypad (data, ready)"
mp_5:       .asciz ""
mp_6:       .asciz "Word-addressed. One instruction, one word."

s_sysinfo:  .asciz " SYSTEM INFO "
s_si_h1:    .asciz "WHAT IS TOMATO"
si_body:    .word si_1, si_2, si_3, si_4, si_5, si_6, si_7, si_8, si_9, 0
si_1:       .asciz "3-variable ALU     out = f(a,b,c) + g(a,b,c) + cin"
si_2:       .asciz "Dual-LUT ALU       two independent LUT3 planes per bit"
si_3:       .asciz "No output mux      LUT feeds the adder. Logic rides arithmetic"
si_4:       .asciz "Polymorphic ALU    dual 8-bit LUT programs, 524288 ops"
si_5:       .asciz "3R-1W register file  three reads, one write on execute"
si_6:       .asciz "256 GPR            32 registers x 8 banks, r0 wired zero"
si_7:       .asciz "Immediate box      imm8, imm12, imm13, imm16, LUI"
si_8:       .asciz "Barrel shifter     LSL / LSR / ASR / ROR, amount = B[4:0]"
si_9:       .asciz "Designed by        Tyrone Marhguy, Penn Engineering 2028"

s_palette:  .asciz " PALETTE "
s_pal_h1:   .asciz "Sixteen indices, as the scanout resolves them"

s_font:     .asciz " FONT CHART "
s_font_h1:  .asciz "All 256 glyph slots; blanks are unpopulated"

s_keypad:   .asciz " KEYPAD TEST "
s_kp_h1:    .asciz "Press a button. Left returns to the menu."
s_kp_glyph: .asciz "Glyph"
s_kp_code:  .asciz "Code"

s_fib:      .asciz " FIBONACCI "
s_fib_keys: .asciz "\x1e \x1f term   \x10 +10   ENTER replay   \x11 back"
s_fib_n:    .asciz "n ="
s_fib_v:    .asciz "F(n) ="

s_snake:    .asciz " SNAKE "
s_sn_keys:  .asciz "\x1e \x1f \x11 \x10 steer    ENTER quit"
s_sn_score: .asciz "EATEN"
s_sn_over:  .asciz "GAME OVER"
s_sn_win:   .asciz "FIELD FULL - YOU WIN"

s_tetris:   .asciz " TETRIS "
s_tt_keys:  .asciz "\x11 \x10 move   \x1e rotate   \x1f drop   ENTER quit"
s_tt_lines: .asciz "LINES"
s_tt_over:  .asciz "GAME OVER"

; Tetromino table: kind*4 + rotation, one 4x4 bitmap per word. Bit 15 is the
; top-left cell, so the shape can be consumed one LSB at a time.
tt_shapes:  .word 0x0F00, 0x2222, 0x00F0, 0x4444     ; I
            .word 0x8E00, 0x6440, 0x0E20, 0x44C0     ; J
            .word 0x2E00, 0x4460, 0x0E80, 0xC440     ; L
            .word 0x6600, 0x6600, 0x6600, 0x6600     ; O
            .word 0x6C00, 0x4620, 0x06C0, 0x8C40     ; S
            .word 0x4E00, 0x4640, 0x0E40, 0x4C40     ; T
            .word 0xC600, 0x2640, 0x0C60, 0x4C80     ; Z
tt_colour:  .word 0x0BDB, 0x09DB, 0x0CDB, 0x0EDB, 0x0ADB, 0x0DDB, 0x04DB

card_body:  .word c_1, c_2, c_3, c_4, c_5, c_6, c_7, 0
c_1:        .asciz "Designed by"
c_2:        .asciz "TYRONE MARHGUY"
c_3:        .asciz "Penn Engineering  2028"
c_4:        .asciz ""
c_5:        .asciz "dual-LUT3 ALU, 524288 ops"
c_6:        .asciz "256 GPR, 8 banks, 3R1W"
c_7:        .asciz "512-row modular microcode"

s_about:    .asciz " ABOUT "
ab_body:    .word ab_1, ab_2, ab_3, ab_4, ab_5, ab_6, ab_7, ab_8, ab_9, 0
ab_1:       .asciz "A 32-bit computer built from 74xx discrete logic,"
ab_2:       .asciz "simulated in Digital, cloned to Verilog, and carried"
ab_3:       .asciz "here on an FPGA while the copper is still under the iron."
ab_4:       .asciz ""
ab_5:       .asciz "Dual-LUT3 ALU. Two planes per bit. 524288 operations."
ab_6:       .asciz "256 GPRs, 3R1W. Immediate box. Eight microcode planes."
ab_7:       .asciz "Dark silicon: 512 burned rows. The plane knows more."
ab_8:       .asciz "Write-back mux: 9 ns tri-state vs 52 ns cascading 151."
ab_9:       .asciz "Byte-lane memory. Overlay word. This is Tomato ISA v1."

; ---- tunables --------------------------------------------------------------
; Iterations per input slice; eight slices make one world step. Sized for the
; 6.25 MHz CPU clock. tb/games_tb.v pokes these four words before releasing
; reset so a step costs microseconds instead of a fifth of a second.
            .org 0xE00
tune_snake: .word 9000
tune_tetris: .word 26000
tune_fib:   .word 4000
tune_boot:  .word 5000

; ---- mutable state ---------------------------------------------------------
            .org 0xE08
v_seed:     .word 0x2545F491
v_capt:     .word 0
dec_buf:    .space 12

            .org 0xE20
tt_row:     .space 20           ; one 10-bit occupancy mask per board row

            .org 0xE40
sn_buf:     .space 128          ; snake body, a ring of packed cells
