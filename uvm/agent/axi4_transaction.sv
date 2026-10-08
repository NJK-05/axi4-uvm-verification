`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_TRANSACTION_SV
`define AXI4_TRANSACTION_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

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

    constraint c_beat_count {
        data.size() == len + 1;
        strb.size() == len + 1;
    }

    `uvm_object_utils(axi4_transaction)

    function new(string name = "axi4_transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("%s id=%0d addr=0x%0h len=%0d size=%0d burst=%s resp=%0d",
                          is_write ? "WRITE" : "READ", id, addr, len, size, burst.name(), resp);
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
               (resp     == rhs_.resp);
    endfunction

endclass

`endif
