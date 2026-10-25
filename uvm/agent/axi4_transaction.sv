`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_TRANSACTION_SV
`define AXI4_TRANSACTION_SV

class axi4_transaction extends uvm_sequence_item;

    typedef enum bit [1:0] {BURST_FIXED = 2'b00, BURST_INCR = 2'b01, BURST_WRAP = 2'b10} axi4_burst_e;

    rand bit            is_write;  // 1 = write transaction, 0 = read transaction
    rand bit [3:0]       id;
    rand bit [31:0]      addr;
    rand bit [7:0]       len;      // AxLEN: number of beats - 1
    rand bit [2:0]       size;     // AxSIZE: bytes per beat = 2**size
    rand axi4_burst_e    burst;
    rand bit [31:0]      data[];   // one entry per beat (write payload or read result)
    rand bit [3:0]       strb[];   // one entry per beat, write-only
         bit [1:0]       resp;     // response code, filled in by driver/monitor, not randomized
         bit             allow_4k_cross;  // stimulus knob, not a protocol field

    constraint c_beat_count {
        data.size() == len + 1;
        strb.size() == len + 1;
    }

    constraint c_size {
        size dist {3'd0 := 2, 3'd1 := 2, 3'd2 := 6};
    }

    constraint c_burst {
        burst dist {BURST_INCR := 5, BURST_FIXED := 2, BURST_WRAP := 3};
        (burst == BURST_WRAP)  -> len inside {1, 3, 7, 15};
        (burst == BURST_WRAP)  -> ((addr & ((1 << size) - 1)) == 0);
        (burst == BURST_FIXED) -> len <= 15;
    }

    constraint c_len {
        len dist {8'd0 := 25, [8'd1:8'd3] :/ 30, [8'd4:8'd15] :/ 30, [8'd16:8'd63] :/ 12, [8'd64:8'd255] :/ 3};
    }

    constraint c_addr {
        if (allow_4k_cross) addr dist {[32'd4032:32'd4095] :/ 70, [32'd0:32'd4031] :/ 20, [32'd4096:32'd4159] :/ 10};
        else                addr dist {[32'd0:32'd4095] :/ 85, [32'd4096:32'd8191] :/ 15};
    }

    constraint c_no_4k_cross {
        (!allow_4k_cross) -> (((addr & 32'hFFF) + ((len + 1) << size)) <= 32'd4096);
    }

    `uvm_object_utils(axi4_transaction)

    function new(string name = "axi4_transaction");
        super.new(name);
    endfunction

    function int unsigned beat_addr(int unsigned n);
        int unsigned nb, aligned, total, wrap_base, a;
        nb      = 1 << size;
        aligned = (addr / nb) * nb;
        total   = nb * (len + 1);
        a       = addr;
        case (burst)
            BURST_FIXED: a = addr;
            BURST_WRAP: begin
                wrap_base = (addr / total) * total;
                if (n != 0) a = aligned + n * nb;
                if (a >= wrap_base + total) a = a - total;
            end
            default: if (n != 0) a = aligned + n * nb;
        endcase
        return a;
    endfunction

    function bit [3:0] lane_mask(int unsigned n);
        int unsigned nb, a, word_base, lo, hi;
        bit [3:0]    m;
        a         = beat_addr(n);
        nb        = 1 << size;
        word_base = (a / 4) * 4;
        lo        = a - word_base;
        hi        = ((a / nb) * nb) + nb - 1 - word_base;
        m         = 4'b0000;
        for (int unsigned l = 0; l < 4; l++) begin
            if (l >= lo && l <= hi) m[l] = 1'b1;
        end
        return m;
    endfunction

    function void post_randomize();
        int unsigned r;
        foreach (strb[i]) begin
            r = $urandom_range(9, 0);
            if      (r < 5) strb[i] = 4'hF;
            else if (r < 6) strb[i] = 4'h0;
            else            strb[i] = $urandom_range(14, 1);
            strb[i] = strb[i] & lane_mask(i);
        end
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("%s id=%0d addr=0x%0h len=%0d size=%0d burst=%s resp=%0d",
                      is_write ? "WRITE" : "READ", id, addr, len, size, burst.name(), resp);
        foreach (data[i]) begin
            s = {s, $sformatf(" d[%0d]=%08h", i, data[i])};
            if (is_write && i < strb.size())
                s = {s, $sformatf("/%04b", strb[i])};
        end
        return s;
    endfunction

    function void do_copy(uvm_object rhs);
        axi4_transaction rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("DO_COPY", "cast of rhs object failed")
        end
        super.do_copy(rhs);
        is_write = rhs_.is_write;
        id       = rhs_.id;
        addr     = rhs_.addr;
        len      = rhs_.len;
        size     = rhs_.size;
        burst    = rhs_.burst;
        data     = rhs_.data;
        strb     = rhs_.strb;
        resp     = rhs_.resp;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        axi4_transaction rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (is_write == rhs_.is_write) &&
               (id       == rhs_.id)       &&
               (addr     == rhs_.addr)     &&
               (len      == rhs_.len)      &&
               (size     == rhs_.size)     &&
               (burst    == rhs_.burst)    &&
               (data     == rhs_.data)     &&
               (strb     == rhs_.strb)     &&
               (resp     == rhs_.resp);
    endfunction

endclass

`endif
