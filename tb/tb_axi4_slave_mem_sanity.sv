`timescale 1ns/1ps

module tb_axi4_slave_mem_sanity;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH   = 4;

    logic aclk;
    logic aresetn;

    axi4_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)) axi (
        .aclk(aclk), .aresetn(aresetn)
    );

    axi4_slave_mem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_DEPTH_BYTES(4096)
    ) dut (.axi(axi.slave));

    always #5 aclk = ~aclk;

    int errors = 0;

    task automatic do_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data, input [7:0] len = 8'd0);
        axi.cb.awid    <= '0;
        axi.cb.awaddr  <= addr;
        axi.cb.awlen   <= len;
        axi.cb.awsize  <= 3'd2;       // 4 bytes/beat
        axi.cb.awburst <= 2'b01;      // INCR
        axi.cb.awvalid <= 1'b1;
        axi.cb.wdata   <= data;
        axi.cb.wstrb   <= 4'hF;
        axi.cb.wlast   <= 1'b1;
        axi.cb.wvalid  <= 1'b1;
        axi.cb.bready  <= 1'b1;
        @(axi.cb);
        while (!axi.cb.awready) @(axi.cb);
        axi.cb.awvalid <= 1'b0;
        while (!axi.cb.wready) @(axi.cb);
        axi.cb.wvalid  <= 1'b0;
        while (!axi.cb.bvalid) @(axi.cb);
        if (axi.cb.bresp !== 2'b00) begin
            $display("[ERROR] write bresp=%0d, expected OKAY", axi.cb.bresp);
            errors++;
        end
        @(axi.cb);
    endtask

    task automatic do_read(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] expected, input [7:0] len = 8'd0);
        axi.cb.arid    <= '0;
        axi.cb.araddr  <= addr;
        axi.cb.arlen   <= len;
        axi.cb.arsize  <= 3'd2;
        axi.cb.arburst <= 2'b01;
        axi.cb.arvalid <= 1'b1;
        axi.cb.rready  <= 1'b1;
        @(axi.cb);
        while (!axi.cb.arready) @(axi.cb);
        axi.cb.arvalid <= 1'b0;
        while (!axi.cb.rvalid) @(axi.cb);
        if (axi.cb.rdata !== expected) begin
            $display("[ERROR] read data=%0h, expected=%0h", axi.cb.rdata, expected);
            errors++;
        end
        if (axi.cb.rresp !== 2'b00) begin
            $display("[ERROR] read rresp=%0d, expected OKAY", axi.cb.rresp);
            errors++;
        end
        @(axi.cb);
    endtask

    initial begin
        aclk    = 0;
        aresetn = 0;
        axi.cb.awvalid <= 0; axi.cb.wvalid <= 0; axi.cb.bready <= 0;
        axi.cb.arvalid <= 0; axi.cb.rready <= 0;
        repeat (4) @(axi.cb);
        aresetn = 1;
        repeat (2) @(axi.cb);

        // Basic single-beat write/read-back
        do_write(32'h0000_0010, 32'hDEAD_BEEF);
        do_read (32'h0000_0010, 32'hDEAD_BEEF);

        // Out-of-range write should get SLVERR
        axi.cb.awid    <= '0;
        axi.cb.awaddr  <= 32'h0000_2000; // beyond MEM_DEPTH_BYTES=4096
        axi.cb.awlen   <= 8'd0;
        axi.cb.awsize  <= 3'd2;
        axi.cb.awburst <= 2'b01;
        axi.cb.awvalid <= 1'b1;
        axi.cb.wdata   <= 32'hCAFE_CAFE;
        axi.cb.wstrb   <= 4'hF;
        axi.cb.wlast   <= 1'b1;
        axi.cb.wvalid  <= 1'b1;
        axi.cb.bready  <= 1'b1;
        @(axi.cb);
        while (!axi.cb.awready) @(axi.cb);
        axi.cb.awvalid <= 1'b0;
        while (!axi.cb.wready) @(axi.cb);
        axi.cb.wvalid  <= 1'b0;
        while (!axi.cb.bvalid) @(axi.cb);
        if (axi.cb.bresp !== 2'b10) begin
            $display("[ERROR] expected SLVERR for out-of-range write, got bresp=%0d", axi.cb.bresp);
            errors++;
        end
        @(axi.cb);

        if (errors == 0)
            $display("[PASS] all sanity checks passed");
        else
            $display("[FAIL] %0d check(s) failed", errors);

        $finish;
    end

endmodule
