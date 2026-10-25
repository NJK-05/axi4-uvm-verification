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
        uvm_top.set_timeout(5ms, 0);
    endfunction

    virtual task run_stimulus();
        axi4_write_read_seq seq;
        seq = axi4_write_read_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_stimulus();
        wait (env.sb.items_checked == env.agent.driver.items_done);
        phase.drop_objection(this);
    endtask

endclass

`endif
