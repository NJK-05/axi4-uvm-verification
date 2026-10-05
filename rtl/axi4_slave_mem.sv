module axi4_slave_mem #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter ID_WIDTH        = 4,
    parameter MEM_DEPTH_BYTES = 4096
) (
    axi4_if.slave axi
);

    localparam STRB_WIDTH = DATA_WIDTH/8;

    typedef enum logic [1:0] {RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10} axi_resp_t;
    typedef enum logic [1:0] {BURST_FIXED = 2'b00, BURST_INCR = 2'b01, BURST_WRAP = 2'b10} axi_burst_t;

    logic [7:0] mem [0:MEM_DEPTH_BYTES-1];

    function automatic logic [ADDR_WIDTH-1:0] next_addr(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [2:0]            size,
        input logic [1:0]            burst,
        input logic [7:0]            len
    );
        logic [ADDR_WIDTH-1:0] incr_addr;
        logic [ADDR_WIDTH-1:0] wrap_size;
        logic [ADDR_WIDTH-1:0] wrap_boundary;
        incr_addr = addr + (1 << size);
        unique case (burst)
            BURST_FIXED: next_addr = addr;
            BURST_WRAP: begin
                wrap_size     = (len + 1) << size;
                wrap_boundary = (addr / wrap_size) * wrap_size + wrap_size;
                next_addr     = (incr_addr == wrap_boundary) ? (wrap_boundary - wrap_size) : incr_addr;
            end
            default: next_addr = incr_addr; // INCR
        endcase
    endfunction

    // ---------------- Write channel FSM ----------------
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wr_state_t;
    wr_state_t wr_state;

    logic [ID_WIDTH-1:0]   wr_id;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [7:0]            wr_len;
    logic [2:0]            wr_size;
    logic [1:0]            wr_burst;
    logic [7:0]            wr_beat_cnt;
    logic                  wr_err;

    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            wr_state    <= W_IDLE;
            axi.awready <= 1'b0;
            axi.wready  <= 1'b0;
            axi.bvalid  <= 1'b0;
            axi.bresp   <= RESP_OKAY;
            axi.bid     <= '0;
        end else begin
            case (wr_state)
                W_IDLE: begin
                    axi.awready <= 1'b1;
                    if (axi.awvalid && axi.awready) begin
                        wr_id       <= axi.awid;
                        wr_addr     <= axi.awaddr;
                        wr_len      <= axi.awlen;
                        wr_size     <= axi.awsize;
                        wr_burst    <= axi.awburst;
                        wr_beat_cnt <= 8'd0;
                        wr_err      <= (axi.awaddr >= MEM_DEPTH_BYTES);
                        axi.awready <= 1'b0;
                        axi.wready  <= 1'b1;
                        wr_state    <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (axi.wvalid && axi.wready) begin
                        if (!wr_err) begin
                            for (int b = 0; b < STRB_WIDTH; b++) begin
                                if (axi.wstrb[b] && ((wr_addr + b) < MEM_DEPTH_BYTES))
                                    mem[wr_addr + b] <= axi.wdata[b*8 +: 8];
                            end
                        end
                        wr_beat_cnt <= wr_beat_cnt + 8'd1;
                        wr_addr     <= next_addr(wr_addr, wr_size, wr_burst, wr_len);
                        if (axi.wlast) begin
                            axi.wready <= 1'b0;
                            axi.bvalid <= 1'b1;
                            axi.bid    <= wr_id;
                            axi.bresp  <= wr_err ? RESP_SLVERR : RESP_OKAY;
                            wr_state   <= W_RESP;
                        end
                    end
                end

                W_RESP: begin
                    if (axi.bvalid && axi.bready) begin
                        axi.bvalid  <= 1'b0;
                        axi.awready <= 1'b1;
                        wr_state    <= W_IDLE;
                    end
                end

                default: wr_state <= W_IDLE;
            endcase
        end
    end

    // ---------------- Read channel FSM ----------------
    typedef enum logic [1:0] {R_IDLE, R_DATA} rd_state_t;
    rd_state_t rd_state;

    logic [ID_WIDTH-1:0]   rd_id;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [7:0]            rd_len;
    logic [2:0]            rd_size;
    logic [1:0]            rd_burst;
    logic [7:0]            rd_beat_cnt;
    logic                  rd_err;

    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            rd_state    <= R_IDLE;
            axi.arready <= 1'b0;
            axi.rvalid  <= 1'b0;
            axi.rlast   <= 1'b0;
            axi.rresp   <= RESP_OKAY;
            axi.rid     <= '0;
            axi.rdata   <= '0;
        end else begin
            case (rd_state)
                R_IDLE: begin
                    axi.arready <= 1'b1;
                    if (axi.arvalid && axi.arready) begin
                        rd_id       <= axi.arid;
                        rd_addr     <= axi.araddr;
                        rd_len      <= axi.arlen;
                        rd_size     <= axi.arsize;
                        rd_burst    <= axi.arburst;
                        rd_beat_cnt <= 8'd0;
                        rd_err      <= (axi.araddr >= MEM_DEPTH_BYTES);
                        axi.arready <= 1'b0;
                        rd_state    <= R_DATA;
                    end
                end

                R_DATA: begin
                    axi.rvalid <= 1'b1;
                    axi.rid    <= rd_id;
                    axi.rresp  <= rd_err ? RESP_SLVERR : RESP_OKAY;
                    for (int b = 0; b < STRB_WIDTH; b++) begin
                        axi.rdata[b*8 +: 8] <= (!rd_err && ((rd_addr + b) < MEM_DEPTH_BYTES)) ? mem[rd_addr + b] : 8'h00;
                    end
                    axi.rlast <= (rd_beat_cnt == rd_len);

                    if (axi.rvalid && axi.rready) begin
                        if (rd_beat_cnt == rd_len) begin
                            axi.rvalid  <= 1'b0;
                            axi.arready <= 1'b1;
                            rd_state    <= R_IDLE;
                        end else begin
                            rd_beat_cnt <= rd_beat_cnt + 8'd1;
                            rd_addr     <= next_addr(rd_addr, rd_size, rd_burst, rd_len);
                        end
                    end
                end

                default: rd_state <= R_IDLE;
            endcase
        end
    end

endmodule
