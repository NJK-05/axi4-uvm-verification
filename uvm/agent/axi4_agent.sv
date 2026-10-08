`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_AGENT_SV
`define AXI4_AGENT_SV

class axi4_agent extends uvm_agent;

    `uvm_component_utils(axi4_agent)

    axi4_sequencer sequencer;
    axi4_driver    driver;
    axi4_monitor   monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = axi4_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = axi4_sequencer::type_id::create("sequencer", this);
            driver    = axi4_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass

`endif
