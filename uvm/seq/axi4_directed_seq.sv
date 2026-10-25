`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_DIRECTED_SEQ_SV
`define AXI4_DIRECTED_SEQ_SV

class axi4_directed_seq extends uvm_sequence #(axi4_transaction);

    `uvm_object_utils(axi4_directed_seq)

    function new(string name = "axi4_directed_seq");
        super.new(name);
    endfunction

    task write_burst(bit [31:0] addr, bit [7:0] len, bit [2:0] size,
                     axi4_transaction::axi4_burst_e burst,
                     bit [31:0] data[], bit [3:0] strb[]);
        axi4_transaction tr = axi4_transaction::type_id::create("wr_tr");
        start_item(tr);
        tr.is_write = 1'b1;
        tr.id       = 4'h0;
        tr.addr     = addr;
        tr.len      = len;
        tr.size     = size;
        tr.burst    = burst;
        tr.data     = data;
        tr.strb     = strb;
        finish_item(tr);
    endtask

    task read_burst(bit [31:0] addr, bit [7:0] len, bit [2:0] size,
                    axi4_transaction::axi4_burst_e burst);
        axi4_transaction tr = axi4_transaction::type_id::create("rd_tr");
        start_item(tr);
        tr.is_write = 1'b0;
        tr.id       = 4'h0;
        tr.addr     = addr;
        tr.len      = len;
        tr.size     = size;
        tr.burst    = burst;
        finish_item(tr);
    endtask

    task body();
        bit [31:0] d[];
        bit [3:0]  s[];

        // single beat
        d = '{32'hDEAD_BEEF};
        s = '{4'hF};
        write_burst(32'h0000_0010, 8'd0, 3'd2, axi4_transaction::BURST_INCR, d, s);
        read_burst (32'h0000_0010, 8'd0, 3'd2, axi4_transaction::BURST_INCR);

        // INCR 4 beats
        d = '{32'h1111_0001, 32'h2222_0002, 32'h3333_0003, 32'h4444_0004};
        s = '{4'hF, 4'hF, 4'hF, 4'hF};
        write_burst(32'h0000_0100, 8'd3, 3'd2, axi4_transaction::BURST_INCR, d, s);
        read_burst (32'h0000_0100, 8'd3, 3'd2, axi4_transaction::BURST_INCR);

        // WRAP 4 beats starting mid-container (0x28 -> 0x2C -> 0x20 -> 0x24)
        d = '{32'hA0A0_A0A0, 32'hB1B1_B1B1, 32'hC2C2_C2C2, 32'hD3D3_D3D3};
        write_burst(32'h0000_0028, 8'd3, 3'd2, axi4_transaction::BURST_WRAP, d, s);
        read_burst (32'h0000_0028, 8'd3, 3'd2, axi4_transaction::BURST_WRAP);
        read_burst (32'h0000_0020, 8'd3, 3'd2, axi4_transaction::BURST_INCR);

        // FIXED 4 beats, last write wins
        d = '{32'hF000_0001, 32'hF000_0002, 32'hF000_0003, 32'hF000_0004};
        write_burst(32'h0000_0040, 8'd3, 3'd2, axi4_transaction::BURST_FIXED, d, s);
        read_burst (32'h0000_0040, 8'd3, 3'd2, axi4_transaction::BURST_FIXED);
        read_burst (32'h0000_0040, 8'd0, 3'd2, axi4_transaction::BURST_INCR);

        // partial WSTRB over an existing word
        d = '{32'hAABB_CCDD};
        s = '{4'hF};
        write_burst(32'h0000_0060, 8'd0, 3'd2, axi4_transaction::BURST_INCR, d, s);
        d = '{32'h1122_3344};
        s = '{4'b0101};
        write_burst(32'h0000_0060, 8'd0, 3'd2, axi4_transaction::BURST_INCR, d, s);
        read_burst (32'h0000_0060, 8'd0, 3'd2, axi4_transaction::BURST_INCR);

        // narrow transfers: byte at lane 1, halfword at lanes 3:2
        d = '{32'h0000_AB00};
        s = '{4'b0010};
        write_burst(32'h0000_0071, 8'd0, 3'd0, axi4_transaction::BURST_INCR, d, s);
        d = '{32'hCDEF_0000};
        s = '{4'b1100};
        write_burst(32'h0000_0072, 8'd0, 3'd1, axi4_transaction::BURST_INCR, d, s);
        read_burst (32'h0000_0071, 8'd0, 3'd0, axi4_transaction::BURST_INCR);
        read_burst (32'h0000_0072, 8'd0, 3'd1, axi4_transaction::BURST_INCR);
        read_burst (32'h0000_0070, 8'd0, 3'd2, axi4_transaction::BURST_INCR);

        // out of range: single beat
        d = '{32'hCAFE_CAFE};
        s = '{4'hF};
        write_burst(32'h0000_2000, 8'd0, 3'd2, axi4_transaction::BURST_INCR, d, s);
        read_burst (32'h0000_2000, 8'd0, 3'd2, axi4_transaction::BURST_INCR);

        // out of range: burst running off the end of memory
        d = '{32'h0BAD_0001, 32'h0BAD_0002, 32'h0BAD_0003, 32'h0BAD_0004};
        s = '{4'hF, 4'hF, 4'hF, 4'hF};
        write_burst(32'h0000_0FF8, 8'd3, 3'd2, axi4_transaction::BURST_INCR, d, s);
        read_burst (32'h0000_0FF8, 8'd3, 3'd2, axi4_transaction::BURST_INCR);
    endtask

endclass

`endif
