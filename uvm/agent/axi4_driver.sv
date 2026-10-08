`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_DRIVER_SV
`define AXI4_DRIVER_SV

class axi4_driver extends uvm_driver #(axi4_transaction);

    `uvm_component_utils(axi4_driver)

    virtual axi4_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    endfunction

    task run_phase(uvm_phase phase);
        vif.cb.awvalid <= 1'b0;
        vif.cb.wvalid  <= 1'b0;
        vif.cb.bready  <= 1'b0;
        vif.cb.arvalid <= 1'b0;
        vif.cb.rready  <= 1'b0;

        forever begin
            axi4_transaction tr;
            seq_item_port.get_next_item(tr);
            if (tr.is_write) drive_write(tr);
            else             drive_read(tr);
            seq_item_port.item_done();
        end
    endtask

    task drive_write(axi4_transaction tr);
        vif.cb.awid    <= tr.id;
        vif.cb.awaddr  <= tr.addr;
        vif.cb.awlen   <= tr.len;
        vif.cb.awsize  <= tr.size;
        vif.cb.awburst <= tr.burst;
        vif.cb.awvalid <= 1'b1;
        vif.cb.bready  <= 1'b1;
        @(vif.cb);
        while (!vif.cb.awready) @(vif.cb);
        vif.cb.awvalid <= 1'b0;

        for (int i = 0; i <= tr.len; i++) begin
            vif.cb.wdata  <= tr.data[i];
            vif.cb.wstrb  <= tr.strb[i];
            vif.cb.wlast  <= (i == tr.len);
            vif.cb.wvalid <= 1'b1;
            @(vif.cb);
            while (!vif.cb.wready) @(vif.cb);
        end
        vif.cb.wvalid <= 1'b0;

        while (!vif.cb.bvalid) @(vif.cb);
        tr.resp = vif.cb.bresp;
        `uvm_info("AXI4_DRIVER", $sformatf("completed %s", tr.convert2string()), UVM_HIGH)
    endtask

    task drive_read(axi4_transaction tr);
        vif.cb.arid    <= tr.id;
        vif.cb.araddr  <= tr.addr;
        vif.cb.arlen   <= tr.len;
        vif.cb.arsize  <= tr.size;
        vif.cb.arburst <= tr.burst;
        vif.cb.arvalid <= 1'b1;
        vif.cb.rready  <= 1'b1;
        @(vif.cb);
        while (!vif.cb.arready) @(vif.cb);
        vif.cb.arvalid <= 1'b0;

        tr.data = new[tr.len + 1];
        for (int i = 0; i <= tr.len; i++) begin
            while (!vif.cb.rvalid) @(vif.cb);
            tr.data[i] = vif.cb.rdata;
            tr.resp    = vif.cb.rresp;
            @(vif.cb);
        end
        `uvm_info("AXI4_DRIVER", $sformatf("completed %s", tr.convert2string()), UVM_HIGH)
    endtask

endclass

`endif
