#include "Vtb_pe.h"
#include "verilated.h"
#include <iostream>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_pe *tb = new Vtb_pe;

    // Initial values (match tb_pe.sv)
    tb->clk = 0;
    tb->rst = 1;
    tb->clear_acc = 0;
    tb->valid_in = 0;
    tb->a_in = 0;
    tb->b_in = 0;

    unsigned long time = 0;
    int prev_clk = tb->clk;
    int negedge_count = 0;

    // Run simulation in half-cycle steps (5 time units per half-cycle)
    for (int step = 0; step < 2000; ++step) {
        prev_clk = tb->clk;
        tb->clk = !tb->clk;
        time += 5;

        tb->eval();

        // release reset at time 20
        if (time == 20) tb->rst = 0;

        // detect negedge
        if (prev_clk == 1 && tb->clk == 0) {
            negedge_count++;
            if (negedge_count == 1) {
                tb->valid_in = 1;
                tb->a_in = 2;
                tb->b_in = 3;
            } else if (negedge_count == 2) {
                tb->a_in = 4;
                tb->b_in = 5;
            } else if (negedge_count == 3) {
                tb->valid_in = 0;
            }
        }

        // after inputs applied and some settling time, print and finish
        if (negedge_count >= 3 && time >= 120) {
            std::cout << "Accumulator = " << (unsigned long)tb->acc_out << std::endl;
            if (tb->acc_out == 26)
                std::cout << "TEST PASSED" << std::endl;
            else
                std::cout << "TEST FAILED" << std::endl;
            break;
        }

        if (Verilated::gotFinish()) break;
    }

    delete tb;
    return 0;
}
