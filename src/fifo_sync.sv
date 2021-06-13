//------------------------------------------------------------------------------
// One clock FIFO
//------------------------------------------------------------------------------
module fifo_sync #(
    parameter ADDR_W      = 10,
    parameter DATA_W      = 8,
    parameter WORDS_TOTAL = 2 ** ADDR_W  // might be less if needed
)(
    input  logic              clk,
    input  logic              rst,
    output logic [ADDR_W:0]   load,
    input  logic [DATA_W-1:0] wdata,
    input  logic              wen,
    output logic              full,
    output logic [DATA_W-1:0] rdata,
    input  logic              ren,
    output logic              rvalid,
    output logic              empty
);

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------
logic              wr;
logic [ADDR_W-1:0] waddr;

logic              rd;
logic [ADDR_W-1:0] raddr;

logic [DATA_W-1:0] mem [2 ** ADDR_W];

//------------------------------------------------------------------------------
// FIFO load counter
//------------------------------------------------------------------------------
assign full  = (load == WORDS_TOTAL);
assign empty = (load == 0);

assign wr = wen & ~full;
assign rd = ren & ~empty;

always_ff @(posedge clk) begin
    if (rst)
        load <= 0;
    else if (wr && !rd)
        load <= load + 1'b1;
    else if (rd && !wr)
        load <= load - 1'b1;
end

//------------------------------------------------------------------------------
// Write side
//------------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst)
        waddr <= 0;
    else if (wr)
        waddr <= waddr + 1'b1;
end

//------------------------------------------------------------------------------
// Read side
//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (rst)
        raddr <= 0;
    else if (rd)
        raddr <= raddr + 1'b1;
end

always_ff @(posedge clk) begin
    if (rst)
        rvalid <= 0;
    else
        rvalid <= rd & ~empty;
end

//------------------------------------------------------------------------------
// RAM module
//------------------------------------------------------------------------------
dpram #(
    .ADDR_W    (ADDR_W),
    .DATA_W    (DATA_W),
    .INIT_FILE ("")
) dpram (
    // Write interface
    .wclk  (clk),
    .wdata (wdata),
    .waddr (waddr),
    .wr    (wr),
    // Read interface
    .rclk  (clk),
    .rdata (rdata),
    .raddr (raddr),
    .rd    (rd)
);

endmodule
