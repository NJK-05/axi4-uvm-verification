`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV

class axi4_monitor extends uvm_monitor;

    `uvm_component_utils(axi4_monitor)

    virtual axi4_if vif;
    uvm_analysis_port #(axi4_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_write();
            monitor_read();
        join
    endtask

    task monitor_write();
        forever begin
            axi4_transaction tr;

            do @(vif.mcb); while (!(vif.mcb.awvalid && vif.mcb.awready));

            tr = axi4_transaction::type_id::create("tr");
            tr.is_write = 1'b1;
            tr.id       = vif.mcb.awid;
            tr.addr     = vif.mcb.awaddr;
            tr.len      = vif.mcb.awlen;
            tr.size     = vif.mcb.awsize;
            tr.burst    = axi4_transaction::axi4_burst_e'(vif.mcb.awburst);
            tr.data     = new[tr.len + 1];
            tr.strb     = new[tr.len + 1];

            for (int i = 0; i <= tr.len; i++) begin
                do @(vif.mcb); while (!(vif.mcb.wvalid && vif.mcb.wready));
                tr.data[i] = vif.mcb.wdata;
                tr.strb[i] = vif.mcb.wstrb;
                if (vif.mcb.wlast !== (i == tr.len))
                    `uvm_error("AXI4_MONITOR", $sformatf("WLAST=%0b on beat %0d of %0d", vif.mcb.wlast, i, tr.len + 1))
            end

            do @(vif.mcb); while (!(vif.mcb.bvalid && vif.mcb.bready));
            tr.resp = vif.mcb.bresp;

            `uvm_info("AXI4_MONITOR", $sformatf("observed %s", tr.convert2string()), UVM_HIGH)
            ap.write(tr);
        end
    endtask

    task monitor_read();
        forever begin
            axi4_transaction tr;

            do @(vif.mcb); while (!(vif.mcb.arvalid && vif.mcb.arready));

            tr = axi4_transaction::type_id::create("tr");
            tr.is_write = 1'b0;
            tr.id       = vif.mcb.arid;
            tr.addr     = vif.mcb.araddr;
            tr.len      = vif.mcb.arlen;
            tr.size     = vif.mcb.arsize;
            tr.burst    = axi4_transaction::axi4_burst_e'(vif.mcb.arburst);
            tr.data     = new[tr.len + 1];

            for (int i = 0; i <= tr.len; i++) begin
                do @(vif.mcb); while (!(vif.mcb.rvalid && vif.mcb.rready));
                tr.data[i] = vif.mcb.rdata;
                tr.resp    = tr.resp | vif.mcb.rresp;
                if (vif.mcb.rlast !== (i == tr.len))
                    `uvm_error("AXI4_MONITOR", $sformatf("RLAST=%0b on beat %0d of %0d", vif.mcb.rlast, i, tr.len + 1))
            end

            `uvm_info("AXI4_MONITOR", $sformatf("observed %s", tr.convert2string()), UVM_HIGH)
            ap.write(tr);
        end
    endtask

endclass

`endif
