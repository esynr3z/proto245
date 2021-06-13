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
    // RX FIFO (Host -> FTDI chip -> FPGA -> FIFO)
    .rxfifo_clk   (sys_clk),
    .rxfifo_rst   (sys_rst),
    .rxfifo_rd    (rxfifo_rd),
    .rxfifo_data  (rxfifo_data),
    .rxfifo_valid (rxfifo_valid),
    .rxfifo_load  (rxfifo_load),
    .rxfifo_empty (rxfifo_empty),
    // TX FIFO (FIFO -> FPGA -> FTDI chip -> Host)
    .txfifo_clk   (sys_clk),
    .txfifo_rst   (sys_rst),
    .txfifo_data  (txfifo_data),
    .txfifo_wr    (txfifo_wr),
    .txfifo_load  (txfifo_load),
    .txfifo_full  (txfifo_full)
);

assign ft_data = ft_oen ? ft_dout : 'z;
assign ft_din  = ft_data;
