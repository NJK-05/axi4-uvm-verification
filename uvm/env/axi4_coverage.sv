`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_COVERAGE_SV
`define AXI4_COVERAGE_SV

class axi4_coverage extends uvm_subscriber #(axi4_transaction);

    `uvm_component_utils(axi4_coverage)

    axi4_transaction t;
    bit has_full_strb;
    bit has_partial_strb;
    bit has_zero_strb;
    int unsigned bl_hits[3][6];
    int unsigned sz_hits[3];
    int unsigned rg_hits[4];
    int unsigned cross_hits[2];

    covergroup cg;
        option.per_instance = 1;

        cp_dir: coverpoint t.is_write {
            bins read  = {1'b0};
            bins write = {1'b1};
        }

        cp_dir_trans: coverpoint t.is_write {
            bins wr_then_rd = (1'b1 => 1'b0);
            bins rd_then_wr = (1'b0 => 1'b1);
            bins wr_then_wr = (1'b1 => 1'b1);
            bins rd_then_rd = (1'b0 => 1'b0);
        }

        cp_burst: coverpoint t.burst {
            bins fixed = {axi4_transaction::BURST_FIXED};
            bins incr  = {axi4_transaction::BURST_INCR};
            bins wrap  = {axi4_transaction::BURST_WRAP};
        }

        cp_size: coverpoint t.size {
            bins bytes1 = {3'd0};
            bins bytes2 = {3'd1};
            bins bytes4 = {3'd2};
        }

        cp_len: coverpoint t.len {
            bins len0     = {8'd0};
            bins len1     = {8'd1};
            bins len2_3   = {[8'd2:8'd3]};
            bins len4_7   = {[8'd4:8'd7]};
            bins len8_15  = {[8'd8:8'd15]};
            bins len16_up = {[8'd16:8'd255]};
        }

        cp_resp: coverpoint t.resp {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        cp_region: coverpoint t.addr {
            bins low      = {[32'd0:32'd1023]};
            bins mid      = {[32'd1024:32'd4031]};
            bins near_end = {[32'd4032:32'd4095]};
            bins oob      = {[32'd4096:$]};
        }

        cp_align: coverpoint t.addr[1:0] {
            bins aligned   = {2'b00};
            bins unaligned = {[2'b01:2'b11]};
        }

        cp_strb_full: coverpoint has_full_strb iff (t.is_write) {
            bins seen = {1'b1};
        }

        cp_strb_partial: coverpoint has_partial_strb iff (t.is_write) {
            bins seen = {1'b1};
        }

        cp_strb_zero: coverpoint has_zero_strb iff (t.is_write) {
            bins seen = {1'b1};
        }

        cx_burst_size: cross cp_burst, cp_size;

        cx_burst_len: cross cp_burst, cp_len {
            ignore_bins wrap_len0    = binsof(cp_burst.wrap)  && binsof(cp_len.len0);
            ignore_bins wrap_len16   = binsof(cp_burst.wrap)  && binsof(cp_len.len16_up);
            ignore_bins fixed_len16  = binsof(cp_burst.fixed) && binsof(cp_len.len16_up);
        }

        cx_dir_resp: cross cp_dir, cp_resp;

        cx_dir_region: cross cp_dir, cp_region;

        cx_size_align: cross cp_size, cp_align;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();
    endfunction

    function void write(axi4_transaction t);
        this.t           = t;
        has_full_strb    = 1'b0;
        has_partial_strb = 1'b0;
        has_zero_strb    = 1'b0;
        if (t.is_write) begin
            foreach (t.strb[i]) begin
                if (t.strb[i] == t.lane_mask(i)) has_full_strb    = 1'b1;
                else if (t.strb[i] == 4'h0)      has_zero_strb    = 1'b1;
                else                             has_partial_strb = 1'b1;
            end
        end
        begin
            int unsigned b, l;
            b = t.burst;
            l = (t.len == 0) ? 0 : (t.len == 1) ? 1 : (t.len <= 3) ? 2 : (t.len <= 7) ? 3 : (t.len <= 15) ? 4 : 5;
            bl_hits[b][l]++;
            if (t.size < 3) sz_hits[t.size]++;
            rg_hits[(t.addr < 1024) ? 0 : (t.addr < 4032) ? 1 : (t.addr < 4096) ? 2 : 3]++;
            if (t.addr < 4096 && t.beat_addr(t.len) >= 4096) cross_hits[t.is_write]++;
        end
        cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("functional coverage %0.2f%%", cg.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf("  dir %0.1f  trans %0.1f  burst %0.1f  size %0.1f  len %0.1f  resp %0.1f  region %0.1f  align %0.1f",
                                   cg.cp_dir.get_inst_coverage(), cg.cp_dir_trans.get_inst_coverage(),
                                   cg.cp_burst.get_inst_coverage(), cg.cp_size.get_inst_coverage(),
                                   cg.cp_len.get_inst_coverage(), cg.cp_resp.get_inst_coverage(),
                                   cg.cp_region.get_inst_coverage(), cg.cp_align.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf("  strb full %0.1f  partial %0.1f  zero %0.1f",
                                   cg.cp_strb_full.get_inst_coverage(), cg.cp_strb_partial.get_inst_coverage(),
                                   cg.cp_strb_zero.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", $sformatf("  cross burst_size %0.1f  burst_len %0.1f  dir_resp %0.1f  dir_region %0.1f  size_align %0.1f",
                                   cg.cx_burst_size.get_inst_coverage(), cg.cx_burst_len.get_inst_coverage(),
                                   cg.cx_dir_resp.get_inst_coverage(), cg.cx_dir_region.get_inst_coverage(),
                                   cg.cx_size_align.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV", "burst x len hits; cols: len0 len1 len2_3 len4_7 len8_15 len16_up", UVM_LOW)
        for (int b = 0; b < 3; b++) begin
            `uvm_info("COV", $sformatf("  %s: %0d %0d %0d %0d %0d %0d", (b == 0) ? "FIXED" : (b == 1) ? "INCR " : "WRAP ",
                                       bl_hits[b][0], bl_hits[b][1], bl_hits[b][2],
                                       bl_hits[b][3], bl_hits[b][4], bl_hits[b][5]), UVM_LOW)
        end
        `uvm_info("COV", $sformatf("  size hits (1B 2B 4B): %0d %0d %0d   region hits (low mid near_end oob): %0d %0d %0d %0d",
                                   sz_hits[0], sz_hits[1], sz_hits[2],
                                   rg_hits[0], rg_hits[1], rg_hits[2], rg_hits[3]), UVM_LOW)
        `uvm_info("COV", $sformatf("  bursts crossing the end of memory: reads %0d  writes %0d", cross_hits[0], cross_hits[1]), UVM_LOW)
    endfunction

endclass

`endif
