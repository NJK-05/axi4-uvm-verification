`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_BASE_TEST_SV
`define AXI4_BASE_TEST_SV

class axi4_base_test extends uvm_test;

    `uvm_component_utils(axi4_base_test)

    axi4_env env;
    virtual axi4_if vif;

    function new(string name = "axi4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi4_env::type_id::create("env", this);
        if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
        uvm_top.set_timeout(5ms, 0);
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (vif.sva_errors != 0) begin
            `uvm_error("SVA", $sformatf("%0d protocol assertion failure(s), see [SVA] lines in the log", vif.sva_errors))
        end
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
