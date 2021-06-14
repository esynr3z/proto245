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
logic [5:0] sys_reset_cnt = '0;
logic sys_rst = 1'b1;
always_ff @(posedge sys_clk) begin
    if (sys_reset_cnt < '1) begin
        sys_rst       <= 1'b1;
        sys_reset_cnt <= sys_reset_cnt + 1'b1;
    end else begin
        sys_rst       <= 1'b0;
    end
end

// FT domain synchronous active high reset
logic [5:0] ft_reset_cnt = '0;
logic ft_rst = 1'b1;
always_ff @(posedge ft_clk) begin
    if (ft_reset_cnt < '1) begin
        ft_rst       <= 1'b1;
        ft_reset_cnt <= ft_reset_cnt + 1'b1;
    end else begin
        ft_rst       <= 1'b0;
    end
end

//------------------------------------------------------------------------------
// FT245 protocol master
//------------------------------------------------------------------------------
`define FIFO245_SYNC

`ifdef FIFO245_SYNC
    `include "sync245.svh"
`else
    `include "async245.svh"
`endif

//------------------------------------------------------------------------------
// Test logic
//------------------------------------------------------------------------------
enum logic [3:0] {
    CMD_WAIT_S,
    CMD_READ_S,
    CMD_PARSE_S,
    TX_TEST_S,
    RX_TEST_S
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
logic [DATA_W-1:0] golden_data, golden_data_next;

assign {cmd_prefix, cmd_code, cmd_data, cmd_suffix} = cmd_shifter;

always_comb begin
    fsm_next         = fsm_state;
    cmd_shifter_next = cmd_shifter;
    rxfifo_rd_next   = rxfifo_rd;
    txfifo_data_next = txfifo_data;
    txfifo_wr_next   = txfifo_wr;
    led0_drv_next    = led0_drv;
    word_cnt_next    = word_cnt;
    golden_data_next = golden_data;

    case (fsm_state)
        CMD_WAIT_S: begin
            txfifo_wr_next = 1'b0;
            rxfifo_rd_next = 1'b0;
            if (!rxfifo_empty) begin
                rxfifo_rd_next = 1'b1;
                fsm_next       = CMD_READ_S;
            end
        end

        CMD_READ_S: begin
            rxfifo_rd_next = 1'b0;
            if (rxfifo_valid) begin
                cmd_shifter_next = {rxfifo_data, cmd_shifter[63:DATA_W]};
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
                    16'hcafe: begin
                        cmd_shifter_next = '0;
                        word_cnt_next    = cmd_data;
                        golden_data_next = '0;
                        txfifo_data_next = 8'h42;
                        fsm_next         = RX_TEST_S;
                    end
                    16'h1ed0: begin
                        cmd_shifter_next = '0;
                        led0_drv_next    = cmd_data[0];
                        fsm_next         = CMD_WAIT_S;
                    end
                    default: begin
                        //do nothing
                    end
                endcase
            end else begin
                fsm_next = CMD_WAIT_S;
            end
        end

        TX_TEST_S: begin
            if (word_cnt == 0) begin
                txfifo_wr_next = 1'b0;
                fsm_next       = CMD_WAIT_S;
            end else if (!txfifo_full) begin
                word_cnt_next    = word_cnt - 1'b1;
                txfifo_data_next = txfifo_data + 1'b1;
            end
        end

        RX_TEST_S: begin
            rxfifo_rd_next = !rxfifo_empty;
            if (rxfifo_valid) begin
                if (word_cnt == 0) begin
                    rxfifo_rd_next = 1'b0;
                    txfifo_wr_next = 1'b1;
                    fsm_next       = CMD_WAIT_S;
                end else begin
                    word_cnt_next = word_cnt - 1'b1;
                end
                txfifo_data_next = (rxfifo_data != golden_data) ?  8'hee : txfifo_data;
                golden_data_next = golden_data + 1'b1;
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
        golden_data <= '0;
    end else begin
        fsm_state   <= fsm_next;
        cmd_shifter <= cmd_shifter_next;
        rxfifo_rd   <= rxfifo_rd_next;
        txfifo_data <= txfifo_data_next;
        txfifo_wr   <= txfifo_wr_next;
        led0_drv    <= led0_drv_next;
        word_cnt    <= word_cnt_next;
        golden_data <= golden_data_next;
    end
end

assign ledr[7:3] = '0;
assign ledr[2] = rxfifo_rd;
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
        sys_heartbeat_cnt <= '0;
    else
        sys_heartbeat_cnt <= sys_heartbeat_cnt + 1'b1;
end
assign ledr[9] = sys_heartbeat_cnt[HEARTBEAT_CNT_W-1];

// FT clock domain
logic [HEARTBEAT_CNT_W-1:0] ft_heartbeat_cnt;
always_ff @(posedge ft_clk) begin
    if (ft_rst)
        ft_heartbeat_cnt <= '0;
    else
        ft_heartbeat_cnt <= ft_heartbeat_cnt + 1'b1;
end
assign ledr[8] = ft_heartbeat_cnt[HEARTBEAT_CNT_W-1];

endmodule
