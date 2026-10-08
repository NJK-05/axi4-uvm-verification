`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_BASE_TEST_SV
`define AXI4_BASE_TEST_SV

class axi4_base_test extends uvm_test;

    `uvm_component_utils(axi4_base_test)

    axi4_env env;

    function new(string name = "axi4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi4_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_write_read_seq seq;
        phase.raise_objection(this);

        seq = axi4_write_read_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);

        #100; // let the read response settle before ending the test
        phase.drop_objection(this);
    endtask

endclass

`endif
