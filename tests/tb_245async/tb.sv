module tb;

// To control from launch scripts
`ifndef DATA_W             `define DATA_W           8  `endif
`ifndef TX_FIFO_SIZE       `define TX_FIFO_SIZE     32 `endif
`ifndef RX_FIFO_SIZE       `define RX_FIFO_SIZE     32 `endif
`ifndef READ_TICKS         `define READ_TICKS       4 `endif
`ifndef WRITE_TICKS        `define WRITE_TICKS      4 `endif

`ifndef FT_CLK_FREQ   `define FT_CLK_FREQ   100e6 `endif
`ifndef FIFO_CLK_FREQ `define FIFO_CLK_FREQ 50e6 `endif

//`define SINGLE_CLK_DOMAIN

//-------------------------------------------------------------------
// Testbench parameters
//-------------------------------------------------------------------
localparam DATA_W             = `DATA_W;
localparam TX_FIFO_SIZE       = `TX_FIFO_SIZE;
localparam RX_FIFO_SIZE       = `RX_FIFO_SIZE;
localparam READ_TICKS         = `READ_TICKS;
localparam WRITE_TICKS        = `WRITE_TICKS;
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
ft245_async_if #(.DATA_W (DATA_W)) ft245_if (.clk (ft_clk));
initial @(negedge ft_rst) ft245_if.serve();

fifo_if  #(
    .DATA_W       (DATA_W),
    .TX_FIFO_SIZE (TX_FIFO_SIZE),
    .RX_FIFO_SIZE (RX_FIFO_SIZE)
) fifo_if (.clk (fifo_clk));

//-------------------------------------------------------------------
// DUT
//-------------------------------------------------------------------
proto245a #(
    .DATA_W            (DATA_W),
    .TX_FIFO_SIZE      (TX_FIFO_SIZE),
    .RX_FIFO_SIZE      (RX_FIFO_SIZE),
    .SINGLE_CLK_DOMAIN (SINGLE_CLK_DOMAIN),
    .READ_TICKS        (READ_TICKS),
    .WRITE_TICKS       (WRITE_TICKS)
) dut (
    // FT interface
    .ft_rst   (ft_rst),
    .ft_clk   (ft_clk),
    .ft_rxfn  (ft245_if.rxfn),
    .ft_txen  (ft245_if.txen),
    .ft_din   (ft245_if.din),
    .ft_dout  (ft245_if.dout),
    .ft_rdn   (ft245_if.rdn),
    .ft_wrn   (ft245_if.wrn),
    .ft_siwu  (),
    // FIFO interface
    .rxfifo_clk   (fifo_clk),
    .rxfifo_rst   (fifo_rst),
    .rxfifo_rd    (fifo_if.rxfifo_rd),
    .rxfifo_data  (fifo_if.rxfifo_data),
    .rxfifo_valid (fifo_if.rxfifo_valid),
    .rxfifo_load  (fifo_if.rxfifo_load),
    .rxfifo_empty (fifo_if.rxfifo_empty),
    .txfifo_clk   (fifo_clk),
    .txfifo_rst   (fifo_rst),
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
`include "test_rx.svh"
`include "test_tx.svh"

`ifndef TESTCASE `define TESTCASE test_tx `endif

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
