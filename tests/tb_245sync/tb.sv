module tb;

// To control from launch scripts
`ifndef DATA_W             `define DATA_W             8  `endif
`ifndef TX_FIFO_SIZE       `define TX_FIFO_SIZE       32 `endif
`ifndef TX_START_THRESHOLD `define TX_START_THRESHOLD 16 `endif
`ifndef TX_BURST_SIZE      `define TX_BURST_SIZE      0  `endif
`ifndef TX_BACKOFF_TIMEOUT `define TX_BACKOFF_TIMEOUT 64 `endif
`ifndef RX_FIFO_SIZE       `define RX_FIFO_SIZE       32 `endif
`ifndef RX_START_THRESHOLD `define RX_START_THRESHOLD 16 `endif
`ifndef RX_BURST_SIZE      `define RX_BURST_SIZE      0  `endif

`ifndef FT_CLK_FREQ   `define FT_CLK_FREQ   60e6 `endif
`ifndef FIFO_CLK_FREQ `define FIFO_CLK_FREQ 48e6 `endif

//`define SINGLE_CLK_DOMAIN

//-------------------------------------------------------------------
// Testbench parameters
//-------------------------------------------------------------------
localparam DATA_W             = `DATA_W;
localparam TX_FIFO_SIZE       = `TX_FIFO_SIZE;
localparam TX_START_THRESHOLD = `TX_START_THRESHOLD;
localparam TX_BURST_SIZE      = `TX_BURST_SIZE;
localparam TX_BACKOFF_TIMEOUT = `TX_BACKOFF_TIMEOUT;
localparam RX_FIFO_SIZE       = `RX_FIFO_SIZE;
localparam RX_START_THRESHOLD = `RX_START_THRESHOLD;
localparam RX_BURST_SIZE      = `RX_BURST_SIZE;
`ifdef SINGLE_CLK_DOMAIN
localparam SINGLE_CLK_DOMAIN  = 1;
`else
localparam SINGLE_CLK_DOMAIN  = 0;
`endif

localparam FT_CLK_FREQ   = `FT_CLK_FREQ;
localparam FIFO_CLK_FREQ = `FIFO_CLK_FREQ;

typedef logic [DATA_W-1:0] data_t;

//-------------------------------------------------------------------
// Clock and reset generation
//-------------------------------------------------------------------
bit ft_clk;
initial forever #(1ns * (0.5 / FT_CLK_FREQ) / 1e-9) ft_clk = ~ft_clk;

bit ft_rst = 1;
initial begin
    repeat(3) @(negedge ft_clk);
    ft_rst = 0;
end

bit fifo_clk;
bit fifo_rst;

`ifdef SINGLE_CLK_DOMAIN
assign fifo_clk = ft_clk;
assign fifo_rst = ft_rst;
`else
initial forever #(1ns * (0.5 / FIFO_CLK_FREQ) / 1e-9) fifo_clk = ~fifo_clk;

initial begin
    fifo_rst = 1;
    repeat(3) @(negedge fifo_clk);
    fifo_rst = 0;
end
`endif

//-------------------------------------------------------------------
// DUT environment
//-------------------------------------------------------------------
ft245_sync_if #(.DATA_W (DATA_W)) ft245_if (.clk (ft_clk));
initial @(negedge ft_rst) ft245_if.serve();

fifo_if  #(
    .DATA_W       (DATA_W),
    .TX_FIFO_SIZE (TX_FIFO_SIZE),
    .RX_FIFO_SIZE (RX_FIFO_SIZE)
) fifo_if (.clk (fifo_clk));

//-------------------------------------------------------------------
// DUT
//-------------------------------------------------------------------
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
) dut (
    // FT interface
    .ft_rst   (ft_rst),
    .ft_clk   (ft_clk),
    .ft_rxfn  (ft245_if.rxfn),
    .ft_txen  (ft245_if.txen),
    .ft_din   (ft245_if.din),
    .ft_dout  (ft245_if.dout),
    .ft_bein  ('1),
    .ft_beout (),
    .ft_rdn   (ft245_if.rdn),
    .ft_wrn   (ft245_if.wrn),
    .ft_oen   (ft245_if.oen),
    .ft_siwu  (),
    // FIFO interface
    .fifo_clk     (fifo_clk),
    .fifo_rst     (fifo_rst),
    .rxfifo_rd    (fifo_if.rxfifo_rd),
    .rxfifo_data  (fifo_if.rxfifo_data),
    .rxfifo_valid (fifo_if.rxfifo_valid),
    .rxfifo_load  (fifo_if.rxfifo_load),
    .rxfifo_empty (fifo_if.rxfifo_empty),
    .txfifo_data  (fifo_if.txfifo_data),
    .txfifo_wr    (fifo_if.txfifo_wr),
    .txfifo_load  (fifo_if.txfifo_load),
    .txfifo_full  (fifo_if.txfifo_full)
);

//-------------------------------------------------------------------
// Utilites
//-------------------------------------------------------------------
`include "utils.svh"

`define START_TEST $display("--- Start %m ---")
`define END_TEST   $display("--- End %m ---")

//-------------------------------------------------------------------
// Tests
//-------------------------------------------------------------------
`include "test_rx_simple.svh"
`include "test_rx_flow_control.svh"
`include "test_rx_thresholds.svh"
`include "test_tx_simple.svh"
`include "test_tx_flow_control.svh"
`include "test_tx_thresholds.svh"

`ifndef TESTCASE `define TESTCASE test_tx_thresholds `endif

initial begin : main
    int test_err;
    wait(!ft_rst && !fifo_rst);
    #1us;
    `TESTCASE(test_err);
    #1us;
    if (test_err)
        $error("!@# TEST FAILED - %0d ERRORS #@!", test_err);
    else
        $display("!@# TEST PASSED #@!");
    $finish();
end

initial begin : watchdog
    #1ms;
    $error("!@# TEST FAILED - TIMEOUT #@!");
    $finish();
end

endmodule
