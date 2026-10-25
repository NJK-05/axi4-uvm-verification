`ifndef AXI4_PKG_SV
`define AXI4_PKG_SV

package axi4_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "axi4_transaction.sv"
    `include "axi4_sequencer.sv"
    `include "axi4_driver.sv"
    `include "axi4_monitor.sv"
    `include "axi4_agent.sv"
    `include "axi4_scoreboard.sv"
    `include "axi4_coverage.sv"
    `include "axi4_env.sv"
    `include "axi4_write_read_seq.sv"
    `include "axi4_directed_seq.sv"
    `include "axi4_rand_seq.sv"
    `include "axi4_base_test.sv"
    `include "axi4_directed_test.sv"
    `include "axi4_rand_test.sv"
    `include "axi4_cross_test.sv"

endpackage

`endif
