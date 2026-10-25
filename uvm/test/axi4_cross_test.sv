`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_CROSS_TEST_SV
`define AXI4_CROSS_TEST_SV

class axi4_cross_test extends axi4_rand_test;

    `uvm_component_utils(axi4_cross_test)

    function new(string name = "axi4_cross_test", uvm_component parent = null);
        super.new(name, parent);
        allow_4k_cross = 1'b1;
    endfunction

endclass

`endif
