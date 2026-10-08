`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_WRITE_READ_SEQ_SV
`define AXI4_WRITE_READ_SEQ_SV

class axi4_write_read_seq extends uvm_sequence #(axi4_transaction);

    `uvm_object_utils(axi4_write_read_seq)

    function new(string name = "axi4_write_read_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction wr_tr, rd_tr;

        wr_tr = axi4_transaction::type_id::create("wr_tr");
        start_item(wr_tr);
        wr_tr.is_write = 1'b1;
        wr_tr.id       = 4'h0;
        wr_tr.addr     = 32'h0000_0010;
        wr_tr.len      = 8'd0;
        wr_tr.size     = 3'd2;
        wr_tr.burst    = axi4_transaction::BURST_INCR;
        wr_tr.data     = new[1];
        wr_tr.strb     = new[1];
        wr_tr.data[0]  = 32'hDEAD_BEEF;
        wr_tr.strb[0]  = 4'hF;
        finish_item(wr_tr);

        rd_tr = axi4_transaction::type_id::create("rd_tr");
        start_item(rd_tr);
        rd_tr.is_write = 1'b0;
        rd_tr.id       = 4'h0;
        rd_tr.addr     = 32'h0000_0010;
        rd_tr.len      = 8'd0;
        rd_tr.size     = 3'd2;
        rd_tr.burst    = axi4_transaction::BURST_INCR;
        finish_item(rd_tr);
    endtask

endclass

`endif
