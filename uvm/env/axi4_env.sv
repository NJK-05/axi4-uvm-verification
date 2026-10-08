`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_ENV_SV
`define AXI4_ENV_SV

class axi4_env extends uvm_env;

    `uvm_component_utils(axi4_env)

    axi4_agent agent;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = axi4_agent::type_id::create("agent", this);
    endfunction

endclass

`endif
