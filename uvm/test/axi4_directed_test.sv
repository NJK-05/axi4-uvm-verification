`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_DIRECTED_TEST_SV
`define AXI4_DIRECTED_TEST_SV

class axi4_directed_test extends axi4_base_test;

    `uvm_component_utils(axi4_directed_test)

    function new(string name = "axi4_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_stimulus();
        axi4_directed_seq seq;
        seq = axi4_directed_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass

`endif
