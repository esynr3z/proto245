//------------------------------------------------------------------------------
// FT245-style synchronous FIFO protocol master.
//
// This protocol is supported on the FTDI USB HighSpeed and SuperSpeed devices:
//   - FT232H
//   - FT2232H
//   - FT232HP/FT233HP
//   - FT2232HP/FT2233HP
//   - FT600Q/FT601Q
//   - FT602Q
//
// Note for the FT2xx chips:
//   Send immediate / wake up signal (SIWU) tied to inactive state.
//
// Note for the FT60x chips:
//   Byte enable signals (BE) are not supported at the moment.
//   So, all transactions have to be word aligned.
//------------------------------------------------------------------------------
module proto245s #(
    parameter DATA_W             = 8,    // FT chip data bus width
    parameter TX_FIFO_SIZE       = 4096, // TXFIFO size in data words
    parameter TX_START_THRESHOLD = 1024, // TXFIFO is ready to trasmit data to the chip if TXFIFO is filled >= threshold
    parameter TX_BURST_SIZE      = 0,    // Maximum number of words inside write (send) burst; use 0 to disable this feature and enable unlimited bursts
    parameter TX_BACKOFF_TIMEOUT = 64,   // Number of ticks after last TXFIFO write when tx transaction will be forced to start
    parameter RX_FIFO_SIZE       = 4096, // RXFIFO size in data words
    parameter RX_START_THRESHOLD = 3072, // RXFIFO is ready to receive data from the chip if RXFIFO FIFO is filled <= threshold
    parameter RX_BURST_SIZE      = 0,    // Maximum number of words inside read (receive) burst; use 0 to disable this feature and enable unlimited bursts
    parameter SINGLE_CLK_DOMAIN  = 0,    // If FT clock and FIFO clocks are from the same clock domain
    parameter TURNAROUND_TICKS   = 4,    // Number of ticks (pause) after every burst
    // Derived parameters
    parameter BE_W           = DATA_W / 8 + (DATA_W % 8 ? 1 : 0),
    parameter TX_FIFO_LOAD_W = $clog2(TX_FIFO_SIZE) + 1,
    parameter RX_FIFO_LOAD_W = $clog2(RX_FIFO_SIZE) + 1
)(
    // FT interface - should be routed directly to IO
    input  logic              ft_rst,   // Active high synchronous reset (ft_clk domain)
    input  logic              ft_clk,   // FT CLOCKOUT signal
    input  logic              ft_rxfn,  // FT RXF# signal
    input  logic              ft_txen,  // FT TXE# signal
    input  logic [DATA_W-1:0] ft_din,   // FT DATA tri-state IOs: input
    output logic [DATA_W-1:0] ft_dout,  // FT DATA tri-state IOs: output
    input  logic [BE_W-1:0]   ft_bein,  // FT BE tri-state IOs: input
    output logic [BE_W-1:0]   ft_beout, // FT BE tri-state IOs: output
    output logic              ft_rdn,   // FT RD# signal
    output logic              ft_wrn,   // FT WR# signal
    output logic              ft_oen,   // FT OE# signal
    output logic              ft_siwu,  // FT SIWU signal
    // RX FIFO (Host -> FTDI chip -> FPGA -> FIFO)
    input  logic                      rxfifo_clk,   // RX FIFO clock
    input  logic                      rxfifo_rst,   // RX FIFO active high synchronous reset
    input  logic                      rxfifo_rd,    // RX FIFO read enable
    output logic [DATA_W-1:0]         rxfifo_data,  // RX FIFO read data
    output logic                      rxfifo_valid, // RX FIFO read data is valid
    output logic [RX_FIFO_LOAD_W-1:0] rxfifo_load,  // RX FIFO load counter
    output logic                      rxfifo_empty, // RX FIFO is empty
    // TX FIFO (FIFO -> FPGA -> FTDI chip -> Host)
    input  logic                      txfifo_clk,   // RX FIFO clock
    input  logic                      txfifo_rst,   // RX FIFO active high synchronous reset
    input  logic [DATA_W-1:0]         txfifo_data,  // TXFIFO write data
    input  logic                      txfifo_wr,    // TXFIFO read enable
    output logic [TX_FIFO_LOAD_W-1:0] txfifo_load,  // TXFIFO load counter
    output logic                      txfifo_full   // TXFIFO is full
);

localparam TX_FIFO_ADDR_W = $clog2(TX_FIFO_SIZE);
localparam RX_FIFO_ADDR_W = $clog2(RX_FIFO_SIZE);

//-------------------------------------------------------------------
// From FT chip
//-------------------------------------------------------------------
(* syn_useioff *) logic [DATA_W-1:0] din;
(* syn_useioff *) logic rxfn;
(* syn_useioff *) logic txen;
logic din_valid, din_valid_next;
logic ft_not_empty, ft_not_full;
logic ft_empty, ft_full;

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        din  <= 0;
        rxfn <= 1'b1;
        txen <= 1'b0;
    end else begin
        din  <= ft_din;
        rxfn <= ft_rxfn;
        txen <= ft_txen;
    end
end

assign ft_not_empty = ~rxfn;
assign ft_empty     =  rxfn;
assign ft_not_full  = ~txen;
assign ft_full      =  txen;

//-------------------------------------------------------------------
// RX FIFO
//-------------------------------------------------------------------
logic [RX_FIFO_LOAD_W-1:0] rxfifo_wload;
logic rxfifo_ready;
logic rxfifo_full;
logic [DATA_W-1:0] rxfifo_wdata;
logic rxfifo_wvalid;

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        rxfifo_wdata  <= 0;
        rxfifo_wvalid <= 1'b0;
    end else begin
        rxfifo_wdata  <= din;
        rxfifo_wvalid <= din_valid & ft_not_empty;
    end
end

generate if (SINGLE_CLK_DOMAIN) begin: rxfifo_sync_genblk
    fifo_sync #(
        .ADDR_W (RX_FIFO_ADDR_W),
        .DATA_W (DATA_W)
    ) rxfifo (
        .clk    (ft_clk),
        .rst    (ft_rst),
        .load   (rxfifo_wload),
        .wdata  (rxfifo_wdata),
        .wen    (rxfifo_wvalid),
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
        .wen    (rxfifo_wvalid),
        .wfull  (rxfifo_full),
        // read side - to FPGA system
        .rclk   (rxfifo_clk),
        .rrst   (rxfifo_rst),
        .rload  (rxfifo_load),
        .rdata  (rxfifo_data),
        .ren    (rxfifo_rd),
        .rvalid (rxfifo_valid),
        .rempty (rxfifo_empty)
    );
end endgenerate
assign rxfifo_ready = (rxfifo_wload <= RX_START_THRESHOLD);

// When rxfifo becomes full, we need to save last data words already pushed out
// from the FT to prevent data loss.
// Maximum rxfifo overflow is 4 words in the current configuration.
// In general, it is equal to the number of ticks between rxfifo_full assertion and ft_rdn deassertion + 1 tick.
// So we have to slightly move full threshold to earn some space for the overflow handling.
localparam RX_OVERFLOW_MAX = 4;
logic rxfifo_almost_full;
assign rxfifo_almost_full = (rxfifo_wload >= (RX_FIFO_SIZE - RX_OVERFLOW_MAX));

//-------------------------------------------------------------------
// RX burst counter
//-------------------------------------------------------------------
logic rx_burst_end;
generate if (RX_BURST_SIZE != 0) begin: rx_burst_genblk
    logic [$clog2(RX_BURST_SIZE)-1:0] rx_burst_cnt;
    always_ff @(posedge ft_clk) begin
        if (ft_rst) begin
            rx_burst_cnt <= 0;
        end else  if (rxfifo_wvalid) begin
            rx_burst_cnt <= rx_burst_cnt + 1'b1;
        end else begin
            rx_burst_cnt <= 0;
        end
    end
    assign rx_burst_end = (rx_burst_cnt == (RX_BURST_SIZE - RX_OVERFLOW_MAX));
end else begin
    assign rx_burst_end = 1'b0;
end endgenerate

//-------------------------------------------------------------------
// TX FIFO
//-------------------------------------------------------------------
logic [DATA_W-1:0] txfifo_rdata, txfifo_rdata_prev;
logic txfifo_rvalid;
logic [TX_FIFO_LOAD_W-1:0] txfifo_rload;
logic txfifo_ready;
logic txfifo_empty;
logic txfifo_ren, txfifo_ren_next;

logic txovrbuf_wr;

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        txfifo_rdata_prev <= '0;
    end else begin
        txfifo_rdata_prev <= txfifo_rdata;
    end
end

generate if (SINGLE_CLK_DOMAIN) begin: txfifo_sync_genblk
    fifo_sync #(
        .ADDR_W (TX_FIFO_ADDR_W),
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
        .wclk   (txfifo_clk),
        .wrst   (txfifo_rst),
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

// we need a timeout to prevent blocking small portion of data inside FIFO,
// so after timeout expires - all data will be transmited
logic [$clog2(TX_BACKOFF_TIMEOUT):0] backoff_timeout_cnt;

// timeout counter resets every time tx fifo being written
always_ff @(posedge ft_clk) begin
    if (ft_rst)
        backoff_timeout_cnt <= 0;
    else if (txfifo_wr || txovrbuf_wr)
        backoff_timeout_cnt <= 0;
    else if (backoff_timeout_cnt < TX_BACKOFF_TIMEOUT)
        backoff_timeout_cnt <= backoff_timeout_cnt + 1'b1;
end

assign txfifo_ready = (txfifo_rload >= TX_START_THRESHOLD) ||
                      ((backoff_timeout_cnt == TX_BACKOFF_TIMEOUT) && !txfifo_empty);

//-------------------------------------------------------------------
// TX overrun buffer
//-------------------------------------------------------------------
// maximum txfifo overrun is 4 words in the current configuration;
// in general, it is equal to the number of ticks between ft_txen assertion and txfifo_ren deassertion plus 1
localparam TX_OVERRUN_MAX = 4;

localparam TXOVRBUF_ADDR_W = $clog2(TX_OVERRUN_MAX);
localparam TXOVRBUF_LOAD_W = TXOVRBUF_ADDR_W + 1;

logic [DATA_W-1:0] txovrbuf_rdata;
logic [DATA_W-1:0] txovrbuf_wdata;
logic txovrbuf_wr0, txovrbuf_wr1;
logic [TXOVRBUF_LOAD_W-1:0] txovrbuf_load;
logic txovrbuf_rvalid;
logic txovrbuf_empty;
logic txovrbuf_ren, txovrbuf_ren_next;
logic txovrbuf_ready;

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        txovrbuf_wr0   <= 1'b0;
        txovrbuf_wr1   <= 1'b0;
        txovrbuf_wdata <= '0;
    end else begin
        txovrbuf_wr0   <= txfifo_rvalid;
        txovrbuf_wr1   <= txovrbuf_wr0;
        txovrbuf_wdata <= txfifo_rdata_prev;
    end
end
assign txovrbuf_wr = txovrbuf_wr0 | txovrbuf_wr1;

// tx overrun buffer - when FT chip becomes full,
// we need to save last data already pushed out from our txfifo to prevent data loss
fifo_sync #(
    .ADDR_W      (TXOVRBUF_ADDR_W),
    .DATA_W      (DATA_W),
    .WORDS_TOTAL (TX_OVERRUN_MAX)
) txovrbuf (
    .clk    (ft_clk),
    .rst    (ft_rst),
    .load   (txovrbuf_load),
    .wdata  (txovrbuf_wdata),
    .wen    (txovrbuf_wr & ft_full),
    .full   (),
    .rdata  (txovrbuf_rdata),
    .ren    (txovrbuf_ren),
    .rvalid (txovrbuf_rvalid),
    .empty  (txovrbuf_empty)
);

assign txovrbuf_ready = (backoff_timeout_cnt == TX_BACKOFF_TIMEOUT) && !txovrbuf_empty;

//-------------------------------------------------------------------
// TX burst counter
//-------------------------------------------------------------------
logic tx_burst_end;
generate if (TX_BURST_SIZE != 0) begin: tx_burst_genblk
    logic [$clog2(TX_BURST_SIZE)-1:0] tx_burst_cnt;
    always_ff @(posedge ft_clk) begin
        if (ft_rst) begin
            tx_burst_cnt <= 0;
        end else  if (txovrbuf_ren || txfifo_ren) begin
            tx_burst_cnt <= tx_burst_cnt + 1'b1;
        end else begin
            tx_burst_cnt <= 0;
        end
    end
    assign tx_burst_end = (tx_burst_cnt == (TX_BURST_SIZE - 1));
end else begin
    assign tx_burst_end = 1'b0;
end endgenerate

//-------------------------------------------------------------------
// Protocol FSM
//-------------------------------------------------------------------
localparam TA_CNT_W   = $clog2(TURNAROUND_TICKS);
localparam TA_CNT_MAX = TA_CNT_W'(TURNAROUND_TICKS - 1);

enum logic [2:0] {
    IDLE_S,
    TX_S,
    TX_OVERRUN_S,
    TURNAROUND_S,
    RX_S,
    RX_OVERFLOW0_S,
    RX_OVERFLOW1_S
} fsm_state, fsm_next;

// To relax timing constraints interface triggers must be places inside IO
(* syn_useioff *) logic [DATA_W-1:0] dout;
(* syn_useioff *) logic rdn;
(* syn_useioff *) logic wrn;
(* syn_useioff *) logic oen;
logic [DATA_W-1:0] dout_next;
logic rdn_next;
logic wrn_next;
logic oen_next;

logic [TA_CNT_W-1:0] ta_cnt, ta_cnt_next;

always_comb begin
    fsm_next          = fsm_state;
    dout_next         = txovrbuf_rvalid ? txovrbuf_rdata : txfifo_rvalid ? txfifo_rdata : '0;
    rdn_next          = rdn;
    wrn_next          = ~(txfifo_rvalid | txovrbuf_rvalid);
    oen_next          = oen;
    din_valid_next    = din_valid;
    ta_cnt_next       = ta_cnt;
    txfifo_ren_next   = txfifo_ren;
    txovrbuf_ren_next = txovrbuf_ren;

    case (fsm_state)
        IDLE_S: begin
            if (ft_not_empty && rxfifo_ready) begin
                // go receive, if FT chip has some data and our receive fifo is empty enough
                oen_next = 1'b0;
                fsm_next = RX_S;
            end else if (ft_not_full && (txfifo_ready || txovrbuf_ready)) begin
                // go transmit, if FT chip has empty space and our tranmsmit fifo is full enough,
                // but if we have data words left from the previous burst we need to transfer them first
                fsm_next = !txovrbuf_empty ? TX_OVERRUN_S : TX_S;
                txovrbuf_ren_next = !txovrbuf_empty;
                txfifo_ren_next   = txovrbuf_empty;
            end
        end

        RX_S: begin
            din_valid_next = ft_not_empty & ~rdn;
            rdn_next       = 1'b0;
            if (ft_empty) begin
                fsm_next       = TURNAROUND_S;
                din_valid_next = 1'b0;
                rdn_next       = 1'b1;
                oen_next       = 1'b1;
            end else if(rxfifo_almost_full || rx_burst_end) begin
                // If rxfifo becomes full while FT buffer is still not empty,
                // we will lost some data words already pushed out from FT due to control signal latency.
                // That's why there is a special handler that solves this problem.
                fsm_next  = RX_OVERFLOW0_S;
                rdn_next  = 1'b1;
            end
        end

        RX_OVERFLOW0_S: begin
            oen_next = 1'b1;
            if (ft_empty) begin
                din_valid_next = 1'b0;
                fsm_next       = TURNAROUND_S;
            end else begin
                din_valid_next = 1'b1;
                fsm_next       = RX_OVERFLOW1_S;
            end
        end

        RX_OVERFLOW1_S: begin
            din_valid_next = 1'b0;
            fsm_next       = TURNAROUND_S;
        end

        TURNAROUND_S: begin
            if (ta_cnt == '0) begin
                ta_cnt_next = TA_CNT_MAX;
                fsm_next    = IDLE_S;
            end else begin
                ta_cnt_next = ta_cnt - 1'b1;
            end
        end

        TX_OVERRUN_S: begin
            txfifo_ren_next = (txovrbuf_load <= 1) && txfifo_ready;
            if (txovrbuf_empty) begin
                txovrbuf_ren_next = 1'b0;
                fsm_next          = txfifo_ready ? TX_S : IDLE_S;
            end
        end

        TX_S : begin
            if (!ft_not_full || txfifo_empty || tx_burst_end) begin
                txfifo_ren_next = 1'b0;
                fsm_next        = TURNAROUND_S;
            end
        end

        default: begin
            //do nothing
        end
   endcase
end

always_ff @(posedge ft_clk) begin
    if (ft_rst) begin
        fsm_state     <= IDLE_S;
        oen           <= 1'b1;
        rdn           <= 1'b1;
        wrn           <= 1'b1;
        dout          <= '0;
        din_valid     <= 1'b0;
        ta_cnt        <= TA_CNT_MAX;
        txfifo_ren    <= 1'b0;
        txovrbuf_ren  <= 1'b0;
    end else begin
        fsm_state     <= fsm_next;
        oen           <= oen_next;
        rdn           <= rdn_next;
        wrn           <= wrn_next;
        dout          <= dout_next;
        din_valid     <= din_valid_next;
        ta_cnt        <= ta_cnt_next;
        txfifo_ren    <= txfifo_ren_next;
        txovrbuf_ren  <= txovrbuf_ren_next;
    end
end

//-------------------------------------------------------------------
// To FT chip
//-------------------------------------------------------------------
assign ft_rdn   = rdn;
assign ft_oen   = oen;
assign ft_wrn   = wrn;
assign ft_dout  = dout;
assign ft_beout = '1;
assign ft_siwu  = 1'b1;

endmodule