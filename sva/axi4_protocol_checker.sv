module axi4_protocol_checker #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
) (
    axi4_if axi
);

    localparam STRB_WIDTH = DATA_WIDTH/8;
    localparam MAX_SIZE   = $clog2(STRB_WIDTH);
    localparam MAX_WAIT   = 16;

    wire [ID_WIDTH-1:0]   awid    = axi.awid;
    wire [ADDR_WIDTH-1:0] awaddr  = axi.awaddr;
    wire [7:0]            awlen   = axi.awlen;
    wire [2:0]            awsize  = axi.awsize;
    wire [1:0]            awburst = axi.awburst;
    wire                  awvalid = axi.awvalid;
    wire                  awready = axi.awready;
    wire [DATA_WIDTH-1:0] wdata   = axi.wdata;
    wire [STRB_WIDTH-1:0] wstrb   = axi.wstrb;
    wire                  wlast   = axi.wlast;
    wire                  wvalid  = axi.wvalid;
    wire                  wready  = axi.wready;
    wire [ID_WIDTH-1:0]   bid     = axi.bid;
    wire [1:0]            bresp   = axi.bresp;
    wire                  bvalid  = axi.bvalid;
    wire                  bready  = axi.bready;
    wire [ID_WIDTH-1:0]   arid    = axi.arid;
    wire [ADDR_WIDTH-1:0] araddr  = axi.araddr;
    wire [7:0]            arlen   = axi.arlen;
    wire [2:0]            arsize  = axi.arsize;
    wire [1:0]            arburst = axi.arburst;
    wire                  arvalid = axi.arvalid;
    wire                  arready = axi.arready;
    wire [ID_WIDTH-1:0]   rid     = axi.rid;
    wire [DATA_WIDTH-1:0] rdata   = axi.rdata;
    wire [1:0]            rresp   = axi.rresp;
    wire                  rlast   = axi.rlast;
    wire                  rvalid  = axi.rvalid;
    wire                  rready  = axi.rready;

    logic                w_active, w_done, r_active;
    logic [8:0]          w_beat, r_beat;
    logic [7:0]          w_len, r_len;
    logic [ID_WIDTH-1:0] w_id, r_id;

    int unsigned n_aw_hs, n_ar_hs, n_b_slverr, n_r_slverr, n_partial_strb, n_b2b_write, n_wrap_rd, n_cross_4k;

    always @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            w_active <= 1'b0;
            w_done   <= 1'b0;
            r_active <= 1'b0;
            w_beat   <= '0;
            r_beat   <= '0;
            w_len    <= '0;
            r_len    <= '0;
            w_id     <= '0;
            r_id     <= '0;
        end else begin
            if (awvalid && awready) begin
                w_active <= 1'b1;
                w_done   <= 1'b0;
                w_beat   <= '0;
                w_len    <= awlen;
                w_id     <= awid;
            end
            if (wvalid && wready) begin
                w_beat <= w_beat + 9'd1;
                if (wlast) begin
                    w_active <= 1'b0;
                    w_done   <= 1'b1;
                end
            end
            if (bvalid && bready) w_done <= 1'b0;
            if (arvalid && arready) begin
                r_active <= 1'b1;
                r_beat   <= '0;
                r_len    <= arlen;
                r_id     <= arid;
            end
            if (rvalid && rready) begin
                r_beat <= r_beat + 9'd1;
                if (rlast) r_active <= 1'b0;
            end
        end
    end

    function void fail(input string name);
        axi.sva_errors++;
        $error("[SVA] %s violated", name);
    endfunction

    function automatic bit crosses_4k(input [ADDR_WIDTH-1:0] addr, input [7:0] len, input [2:0] size);
        logic [ADDR_WIDTH-1:0] aligned, last;
        aligned = (addr >> size) << size;
        last    = aligned + ((len + 1) << size) - 1;
        return (addr[ADDR_WIDTH-1:12] != last[ADDR_WIDTH-1:12]);
    endfunction

    // ---------------- reset and unknown values ----------------
    a_reset_valids_low: assert property (@(posedge axi.aclk)
        !axi.aresetn |-> (awvalid !== 1'b1 && wvalid !== 1'b1 && arvalid !== 1'b1 && bvalid !== 1'b1 && rvalid !== 1'b1))
        else fail("a_reset_valids_low");

    a_ctrl_known: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        !$isunknown({awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready}))
        else fail("a_ctrl_known");

    a_aw_payload_known: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid |-> !$isunknown({awid, awaddr, awlen, awsize, awburst}))
        else fail("a_aw_payload_known");

    a_w_payload_known: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        wvalid |-> !$isunknown({wdata, wstrb, wlast}))
        else fail("a_w_payload_known");

    a_ar_payload_known: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid |-> !$isunknown({arid, araddr, arlen, arsize, arburst}))
        else fail("a_ar_payload_known");

    a_b_payload_known: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        bvalid |-> !$isunknown({bid, bresp}))
        else fail("a_b_payload_known");

    a_r_payload_known: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid |-> !$isunknown({rid, rdata, rresp, rlast}))
        else fail("a_r_payload_known");

    // ---------------- VALID held and payload stable until READY ----------------
    a_aw_hold: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && !awready |=> awvalid)
        else fail("a_aw_hold");

    a_aw_stable: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && !awready |=> $stable({awid, awaddr, awlen, awsize, awburst}))
        else fail("a_aw_stable");

    a_w_hold: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        wvalid && !wready |=> wvalid)
        else fail("a_w_hold");

    a_w_stable: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        wvalid && !wready |=> $stable({wdata, wstrb, wlast}))
        else fail("a_w_stable");

    a_ar_hold: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && !arready |=> arvalid)
        else fail("a_ar_hold");

    a_ar_stable: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && !arready |=> $stable({arid, araddr, arlen, arsize, arburst}))
        else fail("a_ar_stable");

    a_b_hold: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        bvalid && !bready |=> bvalid)
        else fail("a_b_hold");

    a_b_stable: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        bvalid && !bready |=> $stable({bid, bresp}))
        else fail("a_b_stable");

    a_r_hold: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid && !rready |=> rvalid)
        else fail("a_r_hold");

    a_r_stable: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid && !rready |=> $stable({rid, rdata, rresp, rlast}))
        else fail("a_r_stable");

    // ---------------- burst legality (master side) ----------------
    a_aw_burst_legal: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid |-> (awburst != 2'b11 && awsize <= MAX_SIZE))
        else fail("a_aw_burst_legal");

    a_aw_wrap_len: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && awburst == 2'b10 |-> (awlen == 8'd1 || awlen == 8'd3 || awlen == 8'd7 || awlen == 8'd15))
        else fail("a_aw_wrap_len");

    a_aw_wrap_aligned: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && awburst == 2'b10 |-> ((awaddr & ((1 << awsize) - 1)) == 0))
        else fail("a_aw_wrap_aligned");

    a_aw_fixed_len: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && awburst == 2'b00 |-> awlen <= 8'd15)
        else fail("a_aw_fixed_len");

    a_aw_no_4k_cross: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && awburst == 2'b01 |-> (axi.allow_4k_cross || !crosses_4k(awaddr, awlen, awsize)))
        else fail("a_aw_no_4k_cross");

    a_ar_burst_legal: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid |-> (arburst != 2'b11 && arsize <= MAX_SIZE))
        else fail("a_ar_burst_legal");

    a_ar_wrap_len: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && arburst == 2'b10 |-> (arlen == 8'd1 || arlen == 8'd3 || arlen == 8'd7 || arlen == 8'd15))
        else fail("a_ar_wrap_len");

    a_ar_wrap_aligned: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && arburst == 2'b10 |-> ((araddr & ((1 << arsize) - 1)) == 0))
        else fail("a_ar_wrap_aligned");

    a_ar_fixed_len: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && arburst == 2'b00 |-> arlen <= 8'd15)
        else fail("a_ar_fixed_len");

    a_ar_no_4k_cross: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && arburst == 2'b01 |-> (axi.allow_4k_cross || !crosses_4k(araddr, arlen, arsize)))
        else fail("a_ar_no_4k_cross");

    // ---------------- last-beat alignment, ordering, IDs, responses ----------------
    a_wlast_align: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        wvalid && wready |-> (wlast == (w_beat == {1'b0, w_len})))
        else fail("a_wlast_align");

    a_w_needs_aw: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        wvalid && wready |-> w_active)
        else fail("a_w_needs_aw");

    a_rlast_align: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid && rready |-> (rlast == (r_beat == {1'b0, r_len})))
        else fail("a_rlast_align");

    a_b_after_w: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        bvalid |-> w_done)
        else fail("a_b_after_w");

    a_r_after_ar: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid |-> r_active)
        else fail("a_r_after_ar");

    a_bid_match: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        bvalid |-> (bid == w_id))
        else fail("a_bid_match");

    a_rid_match: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid |-> (rid == r_id))
        else fail("a_rid_match");

    a_bresp_legal: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        bvalid |-> (bresp == 2'b00 || bresp == 2'b10))
        else fail("a_bresp_legal");

    a_rresp_legal: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid |-> (rresp == 2'b00 || rresp == 2'b10))
        else fail("a_rresp_legal");

    // ---------------- single outstanding transaction ----------------
    a_aw_single: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && awready |-> (!w_active && !w_done))
        else fail("a_aw_single");

    a_ar_single: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && arready |-> !r_active)
        else fail("a_ar_single");

    // ---------------- bounded response times ----------------
    a_aw_to_wready: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        awvalid && awready |-> ##[1:MAX_WAIT] wready)
        else fail("a_aw_to_wready");

    a_w_to_b: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        wvalid && wready && wlast |-> ##[1:MAX_WAIT] bvalid)
        else fail("a_w_to_b");

    a_ar_to_r: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        arvalid && arready |-> ##[1:MAX_WAIT] rvalid)
        else fail("a_ar_to_r");

    a_r_next_beat: assert property (@(posedge axi.aclk) disable iff (!axi.aresetn)
        rvalid && rready && !rlast |-> ##[1:MAX_WAIT] rvalid)
        else fail("a_r_next_beat");

    // ---------------- covers ----------------
    bit prev_b_hs;

    always @(posedge axi.aclk) begin
        if (axi.aresetn) begin
            if (awvalid && awready)                                   n_aw_hs++;
            if (arvalid && arready)                                   n_ar_hs++;
            if (bvalid && bready && bresp == 2'b10)                   n_b_slverr++;
            if (rvalid && rready && rresp == 2'b10)                   n_r_slverr++;
            if (wvalid && wready && wstrb != {STRB_WIDTH{1'b1}})      n_partial_strb++;
            if (prev_b_hs && awvalid && awready)                      n_b2b_write++;
            if (arvalid && arready && arburst == 2'b10)               n_wrap_rd++;
            if (awvalid && awready && awburst == 2'b01 && crosses_4k(awaddr, awlen, awsize)) n_cross_4k++;
            prev_b_hs <= bvalid && bready;
        end else
            prev_b_hs <= 1'b0;
    end


    final begin
        $display("[SVA] summary: %0d failure(s); covers: aw_hs=%0d ar_hs=%0d b_slverr=%0d r_slverr=%0d partial_strb=%0d b2b_write=%0d wrap_rd=%0d cross_4k=%0d",
                 axi.sva_errors, n_aw_hs, n_ar_hs, n_b_slverr, n_r_slverr, n_partial_strb, n_b2b_write, n_wrap_rd, n_cross_4k);
    end

endmodule
