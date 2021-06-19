localparam TX_FIFO_SIZE       = 4096;
localparam RX_FIFO_SIZE       = 4096;
localparam SINGLE_CLK_DOMAIN  = 1;
localparam READ_TICKS         = 2;
localparam WRITE_TICKS        = 2;
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

proto245a #(
    .DATA_W            (DATA_W),
    .TX_FIFO_SIZE      (TX_FIFO_SIZE),
    .RX_FIFO_SIZE      (RX_FIFO_SIZE),
    .SINGLE_CLK_DOMAIN (SINGLE_CLK_DOMAIN),
    .READ_TICKS        (READ_TICKS),
    .WRITE_TICKS       (WRITE_TICKS)
) proto245 (
    // FT interface - should be routed directly to IO
    .ft_rst   (sys_rst),
    .ft_clk   (sys_clk),
    .ft_rxfn  (ft_rxfn),
    .ft_txen  (ft_txen),
    .ft_din   (ft_din),
    .ft_dout  (ft_dout),
    .ft_rdn   (ft_rdn),
    .ft_wrn   (ft_wrn),
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

assign ft_oen  = 1'b1;
assign ft_data = ft_rdn ? ft_dout : 'z;
assign ft_din  = ft_data;
