; kb_mmio.s — keyboard via MMIO window [21:19]==111 (alternate to IN)
; LUI r7,0x780 → addr low24 0x780000
    LUI     r7, 0x780
    LW      r1, r7, 0          ; data = kb_data
    LW      r2, r7, 1          ; status = kb_ready
    OUT     r1                 ; echo to io_out
    HALT
