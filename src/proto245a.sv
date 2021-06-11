//------------------------------------------------------------------------------
// FT245-style asynchronous FIFO protocol master.
//
// This protocol is supported on the FTDI USB FullSpeed and HighSpeed devices:
//   - FT245R
//   - FT245BL
//   - FT240X
//   - FT232H
//   - FT2232D
//   - FT2232H
//   - FT232HP/FT233HP
//   - FT2232HP/FT2233HP
//
// Note:
//   Send immediate / wake up signal (SIWU) tied to inactive state.
//------------------------------------------------------------------------------
module proto245a #(
    parameter DATA_W             = 8,    // FT chip data bus width
    parameter TX_FIFO_SIZE       = 4096, // TXFIFO size in data words
    parameter RX_FIFO_SIZE       = 4096, // RXFIFO size in data words
    parameter SINGLE_CLK_DOMAIN  = 0,    // If ft_clk and fifo_clk are from the one clock domain (configures FIFOs type)
    parameter READ_TICKS         = 4,    // Active RD# time (ft_clk based; >30ns)
    parameter WRITE_TICKS        = 4,    // Active WR# time (ft_clk based; >30ns)
    parameter TURNAROUND_TICKS   = 8,    // Pause between transactions (ft_clk based; >63ns)
    // Derived parameters
    parameter TX_FIFO_LOAD_W = $clog2(TX_FIFO_SIZE) + 1,
    parameter RX_FIFO_LOAD_W = $clog2(RX_FIFO_SIZE) + 1
)(
    // FT clock and reset
    input  logic              ft_rst,   // Active high synchronous reset (ft_clk domain)
    input  logic              ft_clk,   // FT clock
    // FT interface - should be routed directly to IO
    input  logic              ft_rxfn,  // FT RXF# signal
    input  logic              ft_txen,  // FT TXE# signal
    input  logic [DATA_W-1:0] ft_din,   // FT DATA tri-state IOs: input
    output logic [DATA_W-1:0] ft_dout,  // FT DATA tri-state IOs: output
    output logic              ft_rdn,   // FT RD# signal
    output logic              ft_wrn,   // FT WR# signal
    output logic              ft_siwu,  // FT SIWU signal
    // FIFO interface
    input  logic                      fifo_clk,     // FIFO clock
    input  logic                      fifo_rst,     // Active high synchronous reset (FIFO clock domain)
    input  logic                      rxfifo_rd,    // RXFIFO read enable
    output logic [DATA_W-1:0]         rxfifo_data,  // RXFIFO read data
    output logic                      rxfifo_valid, // RXFIFO read data is valid
    output logic [RX_FIFO_LOAD_W-1:0] rxfifo_load,  // RXFIFO load counter
    output logic                      rxfifo_empty, // RXFIFO is empty
    input  logic [DATA_W-1:0]         txfifo_data,  // TXFIFO write data
    input  logic                      txfifo_wr,    // TXFIFO read enable
    output logic [TX_FIFO_LOAD_W-1:0] txfifo_load,  // TXFIFO load counter
    output logic                      txfifo_full   // TXFIFO is full
);

parameter TX_FIFO_ADDR_W = $clog2(TX_FIFO_SIZE);
parameter RX_FIFO_ADDR_W = $clog2(RX_FIFO_SIZE);

//-------------------------------------------------------------------
// From FT chip
//-------------------------------------------------------------------
(* syn_useioff *) logic [DATA_W-1:0] din;
(* syn_useioff *) logic rxfn_ff0;
logic rxfn_ff1;
(* syn_useioff *) logic txen_ff0;
logic txen_ff1;
logic din_valid, din_valid_next;
logic ft_not_empty, ft_not_full;
logic ft_empty, ft_full;

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        din      <= 0;
        rxfn_ff0 <= 1'b1;
        rxfn_ff1 <= 1'b1;
        txen_ff0 <= 1'b0;
        txen_ff1 <= 1'b0;
    end else begin
        din      <= ft_din;
        rxfn_ff0 <= ft_rxfn;
        rxfn_ff1 <= rxfn_ff0;
        txen_ff0 <= ft_txen;
        txen_ff1 <= txen_ff0;
    end
end

assign ft_not_empty = !rxfn_ff1;
assign ft_empty     =  rxfn_ff1;
assign ft_not_full  = !txen_ff1;
assign ft_full      =  txen_ff1;

//-------------------------------------------------------------------
// RX FIFO
//-------------------------------------------------------------------
logic [RX_FIFO_LOAD_W-1:0] rxfifo_wload;
logic rxfifo_ready;
logic rxfifo_full;
logic [DATA_W-1:0] rxfifo_wdata;
logic rxfifo_wen, rxfifo_wen_next;

assign rxfifo_wdata = din;

generate if (SINGLE_CLK_DOMAIN) begin: rxfifo_sync_genblk
    fifo_sync #(
        .ADDR_W (RX_FIFO_ADDR_W),
        .DATA_W (DATA_W)
    ) rxfifo (
        .clk    (ft_clk),
        .rst    (ft_rst),
        .load   (rxfifo_wload),
        .wdata  (rxfifo_wdata),
        .wen    (rxfifo_wen),
        .full   (rxfifo_full),
        .rdata  (rxfifo_data),
        .ren    (rxfifo_rd),
        .rvalid (rxfifo_valid),
        .empty  (rxfifo_empty)
    );
   assign rxfifo_load = rxfifo_wload;
end else begin: rxfifo_async_genblk
    fifo_async #(
        .ADDR_W (RX_FIFO_ADDR_W),
        .DATA_W (DATA_W)
    ) rxfifo (
        // write side - from FT chip
        .wclk   (ft_clk),
        .wrst   (ft_rst),
        .wload  (rxfifo_wload),
        .wdata  (rxfifo_wdata),
        .wen    (rxfifo_wen),
        .wfull  (rxfifo_full),
        // read side - to FPGA system
        .rclk   (fifo_clk),
        .rrst   (fifo_rst),
        .rload  (rxfifo_load),
        .rdata  (rxfifo_data),
        .ren    (rxfifo_rd),
        .rvalid (rxfifo_valid),
        .rempty (rxfifo_empty)
    );
end endgenerate

//-------------------------------------------------------------------
// TX FIFO
//-------------------------------------------------------------------
logic [DATA_W-1:0] txfifo_rdata;
logic txfifo_rvalid;
logic [TX_FIFO_LOAD_W-1:0] txfifo_rload;
logic txfifo_ready;
logic txfifo_empty;
logic txfifo_ren, txfifo_ren_next;

generate if (SINGLE_CLK_DOMAIN) begin: txfifo_sync_genblk
    fifo_sync #(
        .ADDR_W (RX_FIFO_ADDR_W),
        .DATA_W (DATA_W)
    ) txfifo (
        .clk    (ft_clk),
        .rst    (ft_rst),
        .load   (txfifo_rload),
        .wdata  (txfifo_data),
        .wen    (txfifo_wr),
        .full   (txfifo_full),
        .rdata  (txfifo_rdata),
        .ren    (txfifo_ren),
        .rvalid (txfifo_rvalid),
        .empty  (txfifo_empty)
    );
    assign txfifo_load = txfifo_rload;
end else begin: txfifo_async_genblk
    fifo_async #(
        .ADDR_W (TX_FIFO_ADDR_W),
        .DATA_W (DATA_W)
    ) txfifo (
        // write side - from system
        .wclk   (fifo_clk),
        .wrst   (fifo_rst),
        .wload  (txfifo_load),
        .wdata  (txfifo_data),
        .wen    (txfifo_wr),
        .wfull  (txfifo_full),
        // read side - to FT chip
        .rclk   (ft_clk),
        .rrst   (ft_rst),
        .rload  (txfifo_rload),
        .rdata  (txfifo_rdata),
        .ren    (txfifo_ren),
        .rvalid (txfifo_rvalid),
        .rempty (txfifo_empty)
    );
end endgenerate

//-------------------------------------------------------------------
// Protocol FSM
//-------------------------------------------------------------------
localparam RD_CNT_MAX = READ_TICKS - 1;
localparam RD_CNT_W   = $clog2(READ_TICKS);
localparam WR_CNT_MAX = WRITE_TICKS - 1;
localparam WR_CNT_W   = $clog2(WRITE_TICKS);
localparam TA_CNT_MAX = TURNAROUND_TICKS - 1;
localparam TA_CNT_W   = $clog2(TURNAROUND_TICKS);

enum logic [2:0] {
    IDLE_S,
    PREP_TX_S,
    TX_S,
    RX_S,
    TA_S
} fsm_state, fsm_next;

(* syn_useioff *) logic [DATA_W-1:0] dout;
(* syn_useioff *) logic rdn;
(* syn_useioff *) logic wrn;
logic [DATA_W-1:0] dout_next;
logic rdn_next;
logic wrn_next;

logic [RD_CNT_W-1:0] rd_cnt, rd_cnt_next;
logic [WR_CNT_W-1:0] wr_cnt, wr_cnt_next;
logic [TA_CNT_W-1:0] ta_cnt, ta_cnt_next;

always_comb begin
    fsm_next        = fsm_state;
    dout_next       = dout;
    rdn_next        = rdn;
    wrn_next        = wrn;
    rxfifo_wen_next = 1'b0;
    txfifo_ren_next = 1'b0;
    rd_cnt_next     = rd_cnt;
    wr_cnt_next     = wr_cnt;
    ta_cnt_next     = ta_cnt;

    case (fsm_state)
        IDLE_S: begin
            if (ft_not_empty && !rxfifo_full) begin
                // go receive, if FT chip has some data and our receive fifo is not full
                rdn_next = 1'b0;
                fsm_next = RX_S;
            end else if (ft_not_full && !txfifo_empty) begin
                // go transmit, if FT chip has empty space and our tranmsmit fifo is not empty
                fsm_next        = PREP_TX_S;
                txfifo_ren_next = 1'b1;
            end
        end

        RX_S: begin
            if (rd_cnt == '0) begin
                rd_cnt_next     = RD_CNT_MAX;
                rdn_next        = 1'b1;
                rxfifo_wen_next = 1'b1;
                fsm_next        = TA_S;
            end else begin
                rd_cnt_next = rd_cnt - 1'b1;
            end
        end

        TA_S: begin
            wrn_next = 1'b1;
            if (ta_cnt == '0) begin
                ta_cnt_next = TA_CNT_MAX;
                fsm_next    = IDLE_S;
            end else begin
                ta_cnt_next = ta_cnt - 1'b1;
            end
        end

        PREP_TX_S : begin
            if (txfifo_rvalid) begin
                dout_next = txfifo_rdata;
                fsm_next  = TX_S;
            end
        end

        TX_S : begin
            wrn_next  = 1'b0;
            ta_cnt_next = ta_cnt - 1'b1;
            if (wr_cnt == '0) begin
                wr_cnt_next = WR_CNT_MAX;
                fsm_next    = TA_S;
            end else begin
                wr_cnt_next = wr_cnt - 1'b1;
            end
        end
   endcase
end

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        fsm_state  <= IDLE_S;
        rdn        <= 1'b1;
        wrn        <= 1'b1;
        dout       <= '0;
        rxfifo_wen <= 1'b0;
        txfifo_ren <= 1'b0;
        rd_cnt     <= RD_CNT_MAX;
        wr_cnt     <= WR_CNT_MAX;
        ta_cnt     <= TA_CNT_MAX;
    end else begin
        fsm_state  <= fsm_next;
        rdn        <= rdn_next;
        wrn        <= wrn_next;
        dout       <= dout_next;
        rxfifo_wen <= rxfifo_wen_next;
        txfifo_ren <= txfifo_ren_next;
        rd_cnt     <= rd_cnt_next;
        wr_cnt     <= wr_cnt_next;
        ta_cnt     <= ta_cnt_next;
    end
end

//-------------------------------------------------------------------
// To FT chip
//-------------------------------------------------------------------
assign ft_rdn  = rdn;
assign ft_wrn  = wrn;
assign ft_dout = dout;
assign ft_siwu = 1'b1;

endmodule