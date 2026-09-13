/*
 * Tomato dual-LUT ALU — Verilator gauntlet (32-bit slice).
 * Usage: ./alu_gauntlet [vector_count] [seed]
 */
#include "Valu.h"
#include "verilated.h"
#include "golden.h"

#include <chrono>
#include <cinttypes>
#include <cstdio>
#include <cstdlib>

static uint8_t cin_from_csel(uint8_t csel, uint8_t csr) {
    switch (csel & 7u) {
    case 0: return 0;
    case 1: return 1;
    case 2: return (csr >> 2) & 1u;
    case 3: return (csr >> 0) & 1u;
    case 4: return (csr >> 3) & 1u;
    case 5: return (csr >> 6) & 1u;
    case 6: return (csr >> 5) & 1u;
    default: return (csr >> 4) & 1u;
    }
}

static void fail_vec(uint64_t i, uint8_t lutA, uint8_t lutB,
                     uint32_t A, uint32_t B, uint32_t C, uint8_t csel,
                     uint32_t got, uint32_t exp) {
    std::fprintf(stderr,
        "FAIL @%" PRIu64 ": lutA=%02x lutB=%02x A=%08x B=%08x C=%08x csel=%u "
        "got=%08x exp=%08x\n",
        i, lutA, lutB, A, B, C, csel, got, exp);
    std::exit(1);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    uint64_t n = 1000000ull;
    uint64_t seed = 0xC0FFEEULL;
    if (argc >= 2)
        n = std::strtoull(argv[1], nullptr, 0);
    if (argc >= 3)
        seed = std::strtoull(argv[2], nullptr, 0);

    Valu* top = new Valu;
    top->clk = 0;
    top->flag_we = 0;
    top->csel = 0;
    top->lutA = 0;
    top->lutB = 0;
    top->A = 0;
    top->B = 0;
    top->C = 0;
    top->eval();

    uint64_t checked = 0;
    auto t0 = std::chrono::steady_clock::now();

    top->lutA = 0xAA;
    top->lutB = 0xCC;
    top->C = 0;
    for (unsigned cin_sel = 0; cin_sel < 2; cin_sel++) {
        top->csel = cin_sel;
        for (unsigned a = 0; a < 256; a++) {
            for (unsigned b = 0; b < 256; b++) {
                top->A = a;
                top->B = b;
                top->eval();
                uint32_t exp = tomato_predict32(0xAA, 0xCC, a, b, 0, (uint8_t)cin_sel);
                if ((uint32_t)top->out != exp)
                    fail_vec(checked, 0xAA, 0xCC, a, b, 0, (uint8_t)cin_sel,
                             (uint32_t)top->out, exp);
                checked++;
            }
        }
    }

    top->csel = 0;
    top->lutB = 0;
    top->A = 0;
    top->B = 0;
    top->C = 0;
    for (unsigned lut = 0; lut < 256; lut++) {
        top->lutA = (uint8_t)lut;
        for (unsigned abc = 0; abc < 8; abc++) {
            top->A = (abc >> 0) & 1u;
            top->B = (abc >> 1) & 1u;
            top->C = (abc >> 2) & 1u;
            top->eval();
            uint32_t exp = tomato_predict32((uint8_t)lut, 0, (uint32_t)top->A,
                                            (uint32_t)top->B, (uint32_t)top->C, 0);
            if ((uint32_t)top->out != exp)
                fail_vec(checked, (uint8_t)lut, 0, (uint32_t)top->A, (uint32_t)top->B,
                         (uint32_t)top->C, 0, (uint32_t)top->out, exp);
            checked++;
        }
    }

    uint64_t directed = checked;
    if (n < directed)
        n = directed;

    // Progress cadence (vectors between status lines). Override with
    // GAUNTLET_PROGRESS_EVERY=N — e.g. 100000000 for ~10x chattier logs.
    uint64_t progress_every = 1000000000ull;
    if (const char* pe = std::getenv("GAUNTLET_PROGRESS_EVERY"))
        progress_every = std::strtoull(pe, nullptr, 0);
    if (progress_every == 0)
        progress_every = 1000000000ull;

    std::printf("alu32 start: target=%" PRIu64 " directed=%" PRIu64
                " seed=0x%" PRIx64 " progress_every=%" PRIu64 "\n",
                n, directed, seed, progress_every);
    std::fflush(stdout);

    uint64_t state = seed ? seed : 1;
    uint64_t next_report = directed + progress_every;

    while (checked < n) {
        uint64_t r0 = xs64(state);
        uint64_t r1 = xs64(state);
        uint64_t r2 = xs64(state);

        uint8_t lutA = (uint8_t)(r0);
        uint8_t lutB = (uint8_t)(r0 >> 8);
        uint8_t csel = (uint8_t)((r0 >> 16) & 7u);
        uint8_t do_flag = (uint8_t)(((r0 >> 19) & 63u) == 0);

        uint32_t A = (uint32_t)(r1);
        uint32_t B = (uint32_t)(r1 >> 32);
        uint32_t C = (uint32_t)(r2);

        top->lutA = lutA;
        top->lutB = lutB;
        top->A = A;
        top->B = B;
        top->C = C;
        top->csel = csel;
        top->flag_we = 0;
        top->eval();

        uint8_t cin = cin_from_csel(csel, (uint8_t)top->csr);
        uint32_t exp = tomato_predict32(lutA, lutB, A, B, C, cin);
        if ((uint32_t)top->out != exp)
            fail_vec(checked, lutA, lutB, A, B, C, csel, (uint32_t)top->out, exp);

        if (do_flag) {
            top->flag_we = 1;
            top->clk = 0;
            top->eval();
            top->clk = 1;
            top->eval();
            top->flag_we = 0;
            top->clk = 0;
            top->eval();
        }

        checked++;
        if (checked >= next_report || checked == n) {
            auto t1 = std::chrono::steady_clock::now();
            double sec = std::chrono::duration<double>(t1 - t0).count();
            double rate = sec > 0 ? (double)checked / sec : 0;
            std::printf("progress %" PRIu64 " / %" PRIu64 "  (%.3f Gvec/s)\n",
                        checked, n, rate / 1e9);
            std::fflush(stdout);
            next_report += progress_every;
        }
    }

    auto t1 = std::chrono::steady_clock::now();
    double sec = std::chrono::duration<double>(t1 - t0).count();
    double rate = sec > 0 ? (double)checked / sec : 0;
    std::printf("PASS alu32 vectors=%" PRIu64 " directed=%" PRIu64
                " seed=0x%" PRIx64 " time=%.3fs rate=%.3f Mvec/s\n",
                checked, directed, seed, sec, rate / 1e6);

    delete top;
    return 0;
}
