`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi4_pkg::*;

module tb_axi4_uvm_top;

    logic aclk;
    logic aresetn;

    axi4_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) axi (
        .aclk(aclk), .aresetn(aresetn)
    );

    axi4_slave_mem #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .ID_WIDTH(4),
        .MEM_DEPTH_BYTES(4096)
    ) dut (.axi(axi.slave));

    axi4_protocol_checker chk (.axi(axi));

    always #5 aclk = ~aclk;

    initial begin
        aclk    = 0;
        aresetn = 0;
        repeat (4) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1;
    end

    initial begin
        uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi);
        run_test("axi4_directed_test");
    end

endmodule
