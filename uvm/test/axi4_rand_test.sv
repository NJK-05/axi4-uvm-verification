`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_RAND_TEST_SV
`define AXI4_RAND_TEST_SV

class axi4_rand_test extends axi4_base_test;

    `uvm_component_utils(axi4_rand_test)

    int unsigned num_txns       = 200;
    bit          allow_4k_cross = 1'b0;

    function new(string name = "axi4_rand_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        vif.allow_4k_cross = allow_4k_cross;
    endfunction

    task run_stimulus();
        axi4_rand_seq seq;
        seq = axi4_rand_seq::type_id::create("seq");
        seq.num_txns       = num_txns;
        seq.allow_4k_cross = allow_4k_cross;
        seq.start(env.agent.sequencer);
    endtask

endclass

`endif
