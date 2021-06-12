module top #(
    parameter DATA_W = 8
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
enum logic [3:0] {
    CMD_WAIT_S,
    CMD_READ_S,
    CMD_PARSE_S,
    TX_TEST_S
} fsm_state, fsm_next;

logic [63:0] cmd_shifter, cmd_shifter_next;
logic [7:0] cmd_prefix;
logic [7:0] cmd_suffix;
logic [31:0] cmd_data;
logic [15:0] cmd_code;
logic rxfifo_rd_next;
logic [DATA_W-1:0] txfifo_data_next;
logic txfifo_wr_next;
logic led0_drv, led0_drv_next;
logic [31:0] word_cnt, word_cnt_next;

assign {cmd_prefix, cmd_code, cmd_data, cmd_suffix} = cmd_shifter;

always_comb begin
    fsm_next         = fsm_state;
    cmd_shifter_next = cmd_shifter;
    rxfifo_rd_next   = rxfifo_rd;
    txfifo_data_next = txfifo_data;
    txfifo_wr_next   = txfifo_wr;
    led0_drv_next    = led0_drv;
    word_cnt_next    = word_cnt;

    case (fsm_state)
        CMD_WAIT_S: begin
            if (!rxfifo_empty) begin
                rxfifo_rd_next = 1'b1;
                fsm_next       = CMD_READ_S;
            end
        end

        CMD_READ_S: begin
            rxfifo_rd_next = 1'b0;
            if (rxfifo_valid) begin
                cmd_shifter_next = {rxfifo_data, cmd_shifter[63:8]};
                fsm_next         = CMD_PARSE_S;
            end
        end

        CMD_PARSE_S: begin
            if ((cmd_prefix == 8'hAA) && (cmd_suffix == 8'h55)) begin
                case (cmd_code)
                    16'hbeef: begin
                        cmd_shifter_next = '0;
                        txfifo_wr_next   = 1'b1;
                        txfifo_data_next = '0;
                        word_cnt_next    = cmd_data;
                        fsm_next         = TX_TEST_S;
                    end
                    16'h1ed0: begin
                        cmd_shifter_next = '0;
                        led0_drv_next    = cmd_data[0];
                        fsm_next         = CMD_WAIT_S;
                    end
                endcase
            end else begin
                fsm_next = CMD_WAIT_S;
            end
        end

        TX_TEST_S: begin
            if (word_cnt == 0) begin
                txfifo_wr_next = 0;
                fsm_next       = CMD_WAIT_S;
            end else if (!txfifo_full) begin
                word_cnt_next    = word_cnt - 1'b1;
                txfifo_data_next = txfifo_data + 1'b1;
            end
        end

        default: begin
            //do nothing
        end
   endcase
end

always_ff @(posedge sys_clk) begin
    if (sys_rst) begin
        fsm_state   <= CMD_WAIT_S;
        cmd_shifter <= '0;
        rxfifo_rd   <= 1'b0;
        txfifo_data <= '0;
        txfifo_wr   <= 1'b0;
        led0_drv    <= 1'b0;
        word_cnt    <= '0;
    end else begin
        fsm_state   <= fsm_next;
        cmd_shifter <= cmd_shifter_next;
        rxfifo_rd   <= rxfifo_rd_next;
        txfifo_data <= txfifo_data_next;
        txfifo_wr   <= txfifo_wr_next;
        led0_drv    <= led0_drv_next;
        word_cnt    <= word_cnt_next;
    end
end

assign ledr[1] = txfifo_wr;
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
