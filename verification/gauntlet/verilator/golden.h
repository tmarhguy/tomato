// Shared golden for Verilator gauntlet (matches formal/alu_ref.v).
#pragma once
#include <cstdint>

inline uint32_t tomato_plane32(uint8_t lut, uint32_t A, uint32_t B, uint32_t C) {
    uint32_t r = 0;
    for (int idx = 0; idx < 8; idx++) {
        if (((lut >> idx) & 1u) == 0)
            continue;
        uint32_t xa = (idx & 1) ? A : ~A;
        uint32_t xb = (idx & 2) ? B : ~B;
        uint32_t xc = (idx & 4) ? C : ~C;
        r |= xa & xb & xc;
    }
    return r;
}

inline uint32_t tomato_predict32(uint8_t lutA, uint8_t lutB,
                                 uint32_t A, uint32_t B, uint32_t C, uint8_t cin) {
    return tomato_plane32(lutA, A, B, C) + tomato_plane32(lutB, A, B, C) + (cin & 1u);
}

inline uint8_t tomato_plane8(uint8_t lut, uint8_t A, uint8_t B, uint8_t C) {
    return (uint8_t)tomato_plane32(lut, A, B, C);
}

inline void tomato_predict8(uint8_t lutA, uint8_t lutB,
                            uint8_t A, uint8_t B, uint8_t C, uint8_t cin,
                            uint8_t* sum, uint8_t* cout) {
    unsigned s = (unsigned)tomato_plane8(lutA, A, B, C) +
                 (unsigned)tomato_plane8(lutB, A, B, C) + (cin & 1u);
    *sum = (uint8_t)(s & 0xffu);
    *cout = (uint8_t)((s >> 8) & 1u);
}

inline uint64_t xs64(uint64_t& s) {
    s ^= s >> 12;
    s ^= s << 25;
    s ^= s >> 27;
    return s * 0x2545F4914F6CDD1Dull;
}
