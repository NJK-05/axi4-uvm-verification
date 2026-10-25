`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_ENV_SV
`define AXI4_ENV_SV

class axi4_env extends uvm_env;

    `uvm_component_utils(axi4_env)

    axi4_agent      agent;
    axi4_scoreboard sb;
    axi4_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = axi4_agent::type_id::create("agent", this);
        sb    = axi4_scoreboard::type_id::create("sb", this);
        cov   = axi4_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(sb.analysis_export);
        agent.monitor.ap.connect(cov.analysis_export);
    endfunction

endclass

`endif
