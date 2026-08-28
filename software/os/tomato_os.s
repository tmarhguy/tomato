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
;
; Keyboard contract (rtl/board/keypad.v via MMIO 0x780000):
;   word 0 = keycode (reading it consumes the key), word 1 = ready flag
;   0x1E up   0x1F down   0x11 left   0x10 right   0x0D enter
;   Those four codes are also their own glyphs, so a keycode can be drawn.
;
; Register map
;   r0            zero
;   r1..r5        helper arguments (clobbered)
;   r6,r7         caller temporaries
;   r8            framebuffer base      0x300000
;   r9            keyboard base         0x780000
;   r10           80, the row stride
;   r11..r15      helper scratch
;   r16           link register (JAL r16 / JR r16) — helpers are all leaves
;   r18,r19       screen loop counters
;   r20           menu selection
;   r21           last key
;   r22           scratch
;   r23..r27      attribute constants
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
            ADDI    r20, r0, 4
            JMP     menu_redraw

menu_down:
            ADDI    r20, r20, 1
            ADDI    r6, r0, 5
            CMP     r20, r6
            BLT     menu_redraw
            ZERO    r20
            JMP     menu_redraw

menu_enter:
            CMP     r20, r0
            BEQ     screen_sysinfo
            ADDI    r6, r0, 1
            CMP     r20, r6
            BEQ     screen_palette
            ADDI    r6, r0, 2
            CMP     r20, r6
            BEQ     screen_font
            ADDI    r6, r0, 3
            CMP     r20, r6
            BEQ     screen_keypad
            JMP     screen_about

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
            LA      r4, s_ab_h1
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
            JAL     r16, wait_back
            JMP     main_loop

; ============================================================================
; Composites — these call leaves, so they park the link in r17 themselves
; ============================================================================

; draw_desktop: clear, title bar, footer, menu frame.  clobbers r1..r5,r11..r15
draw_desktop:
            MOV     r17, r16

            ZERO    r3                  ; solid palette 0 — black field
            JAL     r16, cls

            ADDI    r1, r0, 0           ; title bar across the top
            ADDI    r2, r0, 0
            MOV     r3, r25             ; blank cell, white on tomato
            ADDI    r4, r0, 80
            JAL     r16, fill
            ADDI    r1, r0, 2
            ADDI    r2, r0, 0
            MOV     r5, r25
            LA      r4, s_title
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

            ADDI    r1, r0, 4           ; menu frame
            ADDI    r2, r0, 3
            ADDI    r3, r0, 34
            ADDI    r4, r0, 9
            MOV     r5, r27
            JAL     r16, box
            ADDI    r1, r0, 6
            ADDI    r2, r0, 3
            MOV     r5, r26
            LA      r4, s_menu_hd
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

; draw_menu: five entries inside the frame, r20 highlighted.
draw_menu:
            MOV     r17, r16
            ZERO    r18                 ; entry index
            LA      r19, menu_items
dm_entry:
            ADDI    r6, r0, 5
            CMP     r18, r6
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

; getkey: block until a key is pending, return the code in r1.
; Reading word 0 is what drops kb_ready, so status must be read first.
getkey:
            LW      r12, r9, 1
            CMP     r12, r0
            BEQ     getkey
            LW      r1, r9, 0
            JR      r16

; ============================================================================
; Data
; ============================================================================
            .org 0x400

s_title:    .asciz "TOMATO OS  v1   32-bit discrete CPU   Nexys A7-100T"
s_keys:     .asciz "\x1e \x1f move    ENTER select"
s_back:     .asciz "\x11 back"
s_menu_hd:  .asciz " MAIN MENU "

menu_items: .word m_sysinfo, m_palette, m_font, m_keypad, m_about
m_sysinfo:  .asciz "System info"
m_palette:  .asciz "Palette"
m_font:     .asciz "Font chart"
m_keypad:   .asciz "Keypad test"
m_about:    .asciz "About Tomato"

s_sysinfo:  .asciz " SYSTEM INFO "
s_si_h1:    .asciz "The machine"
si_body:    .word si_1, si_2, si_3, si_4, si_5, si_6, si_7, 0
si_1:       .asciz "Architecture   32-bit, dual-LUT3 ALU fused to a ripple adder"
si_2:       .asciz "ALU            out = f(a,b,c) + g(a,b,c) + cin, 3 variables"
si_3:       .asciz "Opcode space   512-row ROM, 8 microcode planes"
si_4:       .asciz "Registers      8 banks x 32 x 32-bit, r0 hardwired zero"
si_5:       .asciz "Memory         16384 words, word-addressed"
si_6:       .asciz "Display        80x60 cells of 8x8, 16-colour palette"
si_7:       .asciz "Carrier        Artix-7 xc7a100tcsg324-1, DVI PMOD on JC+JD"

s_palette:  .asciz " PALETTE "
s_pal_h1:   .asciz "Sixteen indices, as the scanout resolves them"

s_font:     .asciz " FONT CHART "
s_font_h1:  .asciz "All 256 glyph slots; blanks are unpopulated"

s_keypad:   .asciz " KEYPAD TEST "
s_kp_h1:    .asciz "Press a button. Left returns to the menu."
s_kp_glyph: .asciz "Glyph"
s_kp_code:  .asciz "Code"

s_about:    .asciz " ABOUT "
s_ab_h1:    .asciz "Tomato"
ab_body:    .word ab_1, ab_2, ab_3, ab_4, ab_5, 0
ab_1:       .asciz "A 32-bit computer built from 74xx discrete logic,"
ab_2:       .asciz "simulated in Digital, cloned to Verilog, and carried"
ab_3:       .asciz "here on an FPGA while the copper is still under the iron."
ab_4:       .asciz ""
ab_5:       .asciz "Tyrone Marhguy  -  Computer Engineering 28  -  Penn"
