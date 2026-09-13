/*
 * Tomato dual-LUT ALU — Verilator gauntlet (8-bit core / byte slice).
 * Usage: ./alu8_gauntlet [vector_count] [seed]
 */
#include "Valu8b.h"
#include "verilated.h"
#include "golden.h"

#include <chrono>
#include <cinttypes>
#include <cstdio>
#include <cstdlib>

static void fail_vec(uint64_t i, uint8_t lutA, uint8_t lutB,
                     uint8_t A, uint8_t B, uint8_t C, uint8_t cin,
                     uint8_t got_sum, uint8_t exp_sum,
                     uint8_t got_cout, uint8_t exp_cout) {
    std::fprintf(stderr,
        "FAIL @%" PRIu64 ": lutA=%02x lutB=%02x A=%02x B=%02x C=%02x cin=%u "
        "sum got=%02x exp=%02x cout got=%u exp=%u\n",
        i, lutA, lutB, A, B, C, cin, got_sum, exp_sum, got_cout, exp_cout);
    std::exit(1);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    uint64_t n = 1000000ull;
    uint64_t seed = 0xA11C00DEULL;
    if (argc >= 2)
        n = std::strtoull(argv[1], nullptr, 0);
    if (argc >= 3)
        seed = std::strtoull(argv[2], nullptr, 0);

    Valu8b* top = new Valu8b;
    uint64_t checked = 0;
    auto t0 = std::chrono::steady_clock::now();

    for (unsigned lutA = 0; lutA < 256; lutA++) {
        for (unsigned lutB = 0; lutB < 256; lutB++) {
            for (unsigned abc = 0; abc < 8; abc++) {
                for (unsigned cin = 0; cin < 2; cin++) {
                    uint8_t A = (uint8_t)((abc >> 0) & 1u);
                    uint8_t B = (uint8_t)((abc >> 1) & 1u);
                    uint8_t C = (uint8_t)((abc >> 2) & 1u);
                    top->lutA = (uint8_t)lutA;
                    top->lutB = (uint8_t)lutB;
                    top->A = A;
                    top->B = B;
                    top->C = C;
                    top->cin = (uint8_t)cin;
                    top->eval();
                    uint8_t exp_sum, exp_cout;
                    tomato_predict8((uint8_t)lutA, (uint8_t)lutB, A, B, C, (uint8_t)cin,
                                    &exp_sum, &exp_cout);
                    if ((uint8_t)top->sum != exp_sum || (uint8_t)top->cout != exp_cout)
                        fail_vec(checked, (uint8_t)lutA, (uint8_t)lutB, A, B, C, (uint8_t)cin,
                                 (uint8_t)top->sum, exp_sum, (uint8_t)top->cout, exp_cout);
                    checked++;
                }
            }
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

    std::printf("alu8b start: target=%" PRIu64 " directed=%" PRIu64
                " seed=0x%" PRIx64 " progress_every=%" PRIu64 "\n",
                n, directed, seed, progress_every);
    std::fflush(stdout);

    uint64_t state = seed ? seed : 1;
    uint64_t next_report = directed + progress_every;

    while (checked < n) {
        uint64_t r = xs64(state);
        uint8_t lutA = (uint8_t)r;
        uint8_t lutB = (uint8_t)(r >> 8);
        uint8_t A = (uint8_t)(r >> 16);
        uint8_t B = (uint8_t)(r >> 24);
        uint8_t C = (uint8_t)(r >> 32);
        uint8_t cin = (uint8_t)((r >> 40) & 1u);

        top->lutA = lutA;
        top->lutB = lutB;
        top->A = A;
        top->B = B;
        top->C = C;
        top->cin = cin;
        top->eval();

        uint8_t exp_sum, exp_cout;
        tomato_predict8(lutA, lutB, A, B, C, cin, &exp_sum, &exp_cout);
        if ((uint8_t)top->sum != exp_sum || (uint8_t)top->cout != exp_cout)
            fail_vec(checked, lutA, lutB, A, B, C, cin,
                     (uint8_t)top->sum, exp_sum, (uint8_t)top->cout, exp_cout);

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
    std::printf("PASS alu8b vectors=%" PRIu64 " directed=%" PRIu64
                " seed=0x%" PRIx64 " time=%.3fs rate=%.3f Mvec/s\n",
                checked, directed, seed, sec, rate / 1e6);

    delete top;
    return 0;
}
