`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_RAND_SEQ_SV
`define AXI4_RAND_SEQ_SV

class axi4_rand_seq extends uvm_sequence #(axi4_transaction);

    `uvm_object_utils(axi4_rand_seq)

    int unsigned num_txns       = 100;
    bit          allow_4k_cross = 1'b0;

    int unsigned written_words[$];

    function new(string name = "axi4_rand_seq");
        super.new(name);
    endfunction

    function void pick_shape(output axi4_transaction::axi4_burst_e b,
                             output int unsigned lo, output int unsigned hi);
        int unsigned r, cls;
        r = $urandom_range(99, 0);
        if      (r < 50) b = axi4_transaction::BURST_INCR;
        else if (r < 70) b = axi4_transaction::BURST_FIXED;
        else             b = axi4_transaction::BURST_WRAP;

        if (b == axi4_transaction::BURST_WRAP) begin
            cls = $urandom_range(3, 0);
            lo  = (cls == 0) ? 1 : (cls == 1) ? 3 : (cls == 2) ? 7 : 15;
            hi  = lo;
        end else begin
            cls = $urandom_range((b == axi4_transaction::BURST_FIXED) ? 4 : 6, 0);
            case (cls)
                0: begin lo = 0;  hi = 0;   end
                1: begin lo = 1;  hi = 1;   end
                2: begin lo = 2;  hi = 3;   end
                3: begin lo = 4;  hi = 7;   end
                4: begin lo = 8;  hi = 15;  end
                5: begin lo = 16; hi = 63;  end
                default: begin lo = 64; hi = 255; end
            endcase
        end
    endfunction

    function int unsigned pick_size();
        int unsigned r;
        r = $urandom_range(99, 0);
        return (r < 20) ? 0 : (r < 40) ? 1 : 2;
    endfunction

    function void pick_addr_range(output int unsigned lo, output int unsigned hi);
        int unsigned r;
        r = $urandom_range(99, 0);
        if (!allow_4k_cross) begin
            if (r < 85) begin lo = 0;    hi = 4095; end
            else        begin lo = 4096; hi = 8191; end
        end else begin
            if      (r < 70) begin lo = 4032; hi = 4095; end
            else if (r < 90) begin lo = 0;    hi = 4031; end
            else             begin lo = 4096; hi = 4159; end
        end
    endfunction

    task body();
        axi4_transaction wr, rd_same, rd_mixed;
        int unsigned     pick_addr;
        axi4_transaction::axi4_burst_e pb;
        int unsigned     plo, phi, ps, alo, ahi;

        repeat (num_txns) begin
            repeat (($urandom_range(0, 3) == 0) ? 2 : 1) begin
                wr = axi4_transaction::type_id::create("wr");
                wr.allow_4k_cross = allow_4k_cross;
                pick_shape(pb, plo, phi);
                ps = pick_size();
                pick_addr_range(alo, ahi);
                start_item(wr);
                if (!wr.randomize() with {is_write == 1'b1;
                                          burst    == pb;
                                          len inside {[plo:phi]};
                                          size     == ps;
                                          addr inside {[alo:ahi]};})
                    `uvm_fatal("RANDFAIL", "write randomize failed")
                finish_item(wr);

                for (int unsigned n = 0; n <= wr.len; n++) begin
                    if (wr.beat_addr(n) < 4096)
                        written_words.push_back((wr.beat_addr(n) / 4) * 4);
                end
            end

            rd_same = axi4_transaction::type_id::create("rd_same");
            rd_same.allow_4k_cross = allow_4k_cross;
            start_item(rd_same);
            if (!rd_same.randomize() with {is_write == 1'b0;
                                           addr  == wr.addr;
                                           len   == wr.len;
                                           size  == wr.size;
                                           burst == wr.burst;})
                `uvm_fatal("RANDFAIL", "same-shape read randomize failed")
            finish_item(rd_same);

            if (written_words.size() > 0 && ($urandom_range(0, 1) == 1)) begin
                pick_addr = written_words[$urandom_range(written_words.size() - 1, 0)];
                rd_mixed = axi4_transaction::type_id::create("rd_mixed");
                rd_mixed.allow_4k_cross = allow_4k_cross;
                start_item(rd_mixed);
                if (!rd_mixed.randomize() with {is_write == 1'b0;
                                                addr  == pick_addr;})
                    `uvm_fatal("RANDFAIL", "mixed read randomize failed")
                finish_item(rd_mixed);
            end
        end
    endtask

endclass

`endif
