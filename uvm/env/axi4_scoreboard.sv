`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_SCOREBOARD_SV
`define AXI4_SCOREBOARD_SV

class axi4_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi4_scoreboard)

    localparam int unsigned MEM_DEPTH_BYTES = 4096;
    localparam int unsigned BUS_BYTES       = 4;
    localparam bit [1:0]    RESP_OKAY       = 2'b00;
    localparam bit [1:0]    RESP_SLVERR     = 2'b10;

    uvm_analysis_imp #(axi4_transaction, axi4_scoreboard) analysis_export;

    bit [7:0] ref_mem [int unsigned];

    int unsigned items_checked;
    int unsigned writes_checked;
    int unsigned reads_checked;
    int unsigned error_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
    endfunction

    function bit [1:0] predict_write(axi4_transaction t);
        bit [1:0]    r;
        int unsigned a, base;
        r = RESP_OKAY;
        for (int unsigned n = 0; n <= t.len; n++) begin
            a = t.beat_addr(n);
            if (a >= MEM_DEPTH_BYTES) begin
                r = RESP_SLVERR;
            end else begin
                base = (a / BUS_BYTES) * BUS_BYTES;
                for (int unsigned lane = 0; lane < BUS_BYTES; lane++) begin
                    if (t.strb[n][lane])
                        ref_mem[base + lane] = t.data[n][lane*8 +: 8];
                end
            end
        end
        return r;
    endfunction

    function void predict_read(axi4_transaction t, axi4_transaction exp);
        int unsigned a, base;
        bit [7:0]    v;
        bit [3:0]    mask;
        exp.resp = RESP_OKAY;
        for (int unsigned n = 0; n <= t.len; n++) begin
            a    = t.beat_addr(n);
            mask = t.lane_mask(n);
            base = (a / BUS_BYTES) * BUS_BYTES;
            if (a >= MEM_DEPTH_BYTES) exp.resp = RESP_SLVERR;
            for (int unsigned lane = 0; lane < BUS_BYTES; lane++) begin
                if (mask[lane]) begin
                    v = 8'h00;
                    if (a < MEM_DEPTH_BYTES && ref_mem.exists(base + lane))
                        v = ref_mem[base + lane];
                    exp.data[n][lane*8 +: 8] = v;
                end
            end
        end
    endfunction

    function void write(axi4_transaction t);
        axi4_transaction exp;
        items_checked++;

        if (t.size > 2) begin
            error_count++;
            `uvm_error("SB_UNSUPPORTED", $sformatf("size=%0d exceeds bus width: %s", t.size, t.convert2string()))
            return;
        end

        exp = axi4_transaction::type_id::create("exp");
        exp.copy(t);

        if (t.is_write) begin
            exp.resp = predict_write(t);
            writes_checked++;
        end else begin
            predict_read(t, exp);
            reads_checked++;
        end

        if (!exp.do_compare(t, null)) begin
            error_count++;
            `uvm_error("SB_MISMATCH", $sformatf("\n  expected: %s\n  observed: %s", exp.convert2string(), t.convert2string()))
        end else begin
            `uvm_info("SB_MATCH", t.convert2string(), UVM_HIGH)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (items_checked == 0) begin
            `uvm_error("SB_EMPTY", "scoreboard observed no transactions")
        end
        `uvm_info("SB_SUMMARY", $sformatf("checked %0d writes, %0d reads, %0d mismatches",
                                          writes_checked, reads_checked, error_count), UVM_LOW)
    endfunction

endclass

`endif
