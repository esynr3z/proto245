module top #(
    parameter DATA_W = 8,
    parameter TEST_WORDS_TOTAL = 100 * 1024 * 1024
)(
    // dev board
    input        max10_clk1_50,
    input  [1:0] key,
    output [9:0] ledr,
    input  [9:0] sw,
    // ft board
    output              ft_oen,
    input               ft_clk,
    output              ft_siwu,
    output              ft_wrn,
    output              ft_rdn,
    input               ft_txen,
    input               ft_rxfn,
    inout  [DATA_W-1:0] ft_data
);

//------------------------------------------------------------------------------
// Clocks and resets
//------------------------------------------------------------------------------
logic sys_clk;
assign sys_clk = max10_clk1_50;

// System synchronous active high reset
logic [5:0] sys_reset_cnt = 0;
logic sys_rst = 1;
always_ff @(posedge sys_clk) begin
    if (sys_reset_cnt < '1) begin
        sys_rst       <= 1;
        sys_reset_cnt <= sys_reset_cnt + 1;
    end else begin
        sys_rst       <= 0;
    end
end

// FT domain synchronous active high reset
logic [5:0] ft_reset_cnt = 0;
logic ft_rst = 1;
always_ff @(posedge ft_clk) begin
    if (ft_reset_cnt < '1) begin
        ft_rst       <= 1;
        ft_reset_cnt <= ft_reset_cnt + 1;
    end else begin
        ft_rst       <= 0;
    end
end

//------------------------------------------------------------------------------
// FT245 protocol master
//------------------------------------------------------------------------------
localparam TX_FIFO_SIZE       = 4096;
localparam TX_START_THRESHOLD = 1024;
localparam TX_BURST_SIZE      = 0;
localparam TX_BACKOFF_TIMEOUT = 64;
localparam RX_FIFO_SIZE       = 4096;
localparam RX_START_THRESHOLD = 3072;
localparam RX_BURST_SIZE      = 0;
localparam SINGLE_CLK_DOMAIN  = 0;
localparam TX_FIFO_LOAD_W     = $clog2(TX_FIFO_SIZE) + 1;
localparam RX_FIFO_LOAD_W     = $clog2(RX_FIFO_SIZE) + 1;

logic [DATA_W-1:0] ft_din, ft_dout;

logic                      rxfifo_rd;
logic [DATA_W-1:0]         rxfifo_data;
logic                      rxfifo_valid;
logic [RX_FIFO_LOAD_W-1:0] rxfifo_load;
logic                      rxfifo_empty;
logic [DATA_W-1:0]         txfifo_data;
logic                      txfifo_wr;
logic [TX_FIFO_LOAD_W-1:0] txfifo_load;
logic                      txfifo_full;

proto245s #(
    .DATA_W             (DATA_W),
    .TX_FIFO_SIZE       (TX_FIFO_SIZE),
    .TX_START_THRESHOLD (TX_START_THRESHOLD),
    .TX_BURST_SIZE      (TX_BURST_SIZE),
    .TX_BACKOFF_TIMEOUT (TX_BACKOFF_TIMEOUT),
    .RX_FIFO_SIZE       (RX_FIFO_SIZE),
    .RX_START_THRESHOLD (RX_START_THRESHOLD),
    .RX_BURST_SIZE      (RX_BURST_SIZE),
    .SINGLE_CLK_DOMAIN  (SINGLE_CLK_DOMAIN)
) proto245 (
    // FT interface - should be routed directly to IO
    .ft_rst   (ft_rst),
    .ft_clk   (ft_clk),
    .ft_rxfn  (ft_rxfn),
    .ft_txen  (ft_txen),
    .ft_din   (ft_din),
    .ft_dout  (ft_dout),
    .ft_bein  (0),
    .ft_beout (),
    .ft_rdn   (ft_rdn),
    .ft_wrn   (ft_wrn),
    .ft_oen   (ft_oen),
    .ft_siwu  (ft_siwu),
    // FIFO interface
    .fifo_clk     (sys_clk),
    .fifo_rst     (sys_rst),
    .rxfifo_rd    (rxfifo_rd),
    .rxfifo_data  (rxfifo_data),
    .rxfifo_valid (rxfifo_valid),
    .rxfifo_load  (rxfifo_load),
    .rxfifo_empty (rxfifo_empty),
    .txfifo_data  (txfifo_data),
    .txfifo_wr    (txfifo_wr),
    .txfifo_load  (txfifo_load),
    .txfifo_full  (txfifo_full)
);

assign ft_data = ft_oen ? ft_dout : 'z;
assign ft_din  = ft_data;

//------------------------------------------------------------------------------
// Test logic
//------------------------------------------------------------------------------
// Read out RX fifo to read command
always_ff @(posedge sys_clk) begin
    if (sys_rst)
        rxfifo_rd <= 0;
    else
        rxfifo_rd <= ~rxfifo_empty;
end

// Receive command and parse it
logic [31:0] cmd_word;
always_ff @(posedge sys_clk) begin
    if (sys_rst)
        cmd_word <= 0;
    else if (rxfifo_valid)
        cmd_word <= {rxfifo_data, cmd_word[31-:24]};
    else if (!rxfifo_valid && rxfifo_empty)
        cmd_word <= 0;
end

logic do_test, do_led0_on, do_led0_off;
always_ff @(posedge sys_clk) begin
    do_test     <= 1'b0;
    do_led0_on  <= 1'b0;
    do_led0_off <= 1'b0;
    case (cmd_word)
        32'hbadc0ffe: do_test     <= 1'b1;
        32'h001711ED: do_led0_on  <= 1'b1;
        32'h00ff11ED: do_led0_off <= 1'b1;
    endcase
end

// TX FIFO fill
logic [$clog2(TEST_WORDS_TOTAL):0] word_cnt;
logic tx_en;
always @(posedge sys_clk) begin
    if (sys_rst) begin
        word_cnt    <= 0;
        tx_en       <= 0;
        txfifo_data <= 0;
        txfifo_wr   <= 0;
    end else if (tx_en) begin
        if (word_cnt >= (TEST_WORDS_TOTAL - 1)) begin
            word_cnt    <= 0;
            txfifo_data <= 0;
            tx_en       <= 0;
            txfifo_wr   <= 0;
        end else if (!txfifo_full) begin
            word_cnt    <= word_cnt + 1'b1;
            txfifo_data <= txfifo_data + 1'b1;
        end
    end else if (do_test) begin
        tx_en     <= 1'b1;
        txfifo_wr <= 1'b1;
    end
end
assign ledr[1] = tx_en;

logic led0_drv;
always_ff @(posedge sys_clk) begin
    if (sys_rst)
        led0_drv <= 0;
    else if (do_led0_on)
        led0_drv <= 1'b1;
    else if (do_led0_off)
        led0_drv <= 1'b0;
end
assign ledr[0] = led0_drv;

//------------------------------------------------------------------------------
// Heartbeats
//------------------------------------------------------------------------------
localparam HEARTBEAT_CNT_W = 25;

// System clock domain
logic [HEARTBEAT_CNT_W-1:0] sys_heartbeat_cnt;
always_ff @(posedge sys_clk) begin
    if (sys_rst)
        sys_heartbeat_cnt <= 0;
    else
        sys_heartbeat_cnt <= sys_heartbeat_cnt + 1;
end
assign ledr[9] = sys_heartbeat_cnt[HEARTBEAT_CNT_W-1];

// FT clock domain
logic [HEARTBEAT_CNT_W-1:0] ft_heartbeat_cnt;
always_ff @(posedge ft_clk) begin
    if (ft_rst)
        ft_heartbeat_cnt <= 0;
    else
        ft_heartbeat_cnt <= ft_heartbeat_cnt + 1;
end
assign ledr[8] = ft_heartbeat_cnt[HEARTBEAT_CNT_W-1];

endmodule
