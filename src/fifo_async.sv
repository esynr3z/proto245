//------------------------------------------------------------------------------
// Two clock (asynchronous) FIFO
//------------------------------------------------------------------------------
module fifo_async #(
    parameter ADDR_W      = 10,
    parameter DATA_W      = 8,
    parameter WORDS_TOTAL = 2 ** ADDR_W, // might be less if needed
    // Derived parameters
    parameter PTR_W       = ADDR_W + 1
)(
    // write side
    input  logic              wclk,
    input  logic              wrst,
    output logic [ADDR_W:0]   wload,
    input  logic [DATA_W-1:0] wdata,
    input  logic              wen,
    output logic              wfull,
    // read sidemode
    input  logic              rclk,
    input  logic              rrst,
    output logic [ADDR_W:0]   rload,
    output logic [DATA_W-1:0] rdata,
    input  logic              ren,
    output logic              rvalid,
    output logic              rempty
);

//------------------------------------------------------------------------------
// Functions
//------------------------------------------------------------------------------
integer i;
function [PTR_W-1:0] gray2bin (input [PTR_W-1:0] gray);
    for (i=0; i<PTR_W; i=i+1) begin
        gray2bin[i] = ^(gray >> i);
    end
endfunction

function [PTR_W-1:0] bin2gray (input [PTR_W-1:0] bin);
    bin2gray = (bin >> 1) ^ bin;
endfunction

function [PTR_W-1:0] load (input [PTR_W-1:0] wptr, input [PTR_W-1:0] rptr);
    load = (rptr <= wptr)? (wptr - rptr) : wptr + (2 * WORDS_TOTAL - rptr);
endfunction

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------
logic             wr;
logic [PTR_W-1:0] wptr;
logic [PTR_W-1:0] wptr_next;
logic [PTR_W-1:0] wptr_sync0;
logic [PTR_W-1:0] wptr_sync1;
logic [PTR_W-1:0] wptr_sync1_bin;
logic [PTR_W-1:0] waddr;

logic             rd;
logic [PTR_W-1:0] rptr;
logic [PTR_W-1:0] rptr_next;
logic [PTR_W-1:0] rptr_sync0;
logic [PTR_W-1:0] rptr_sync1;
logic [PTR_W-1:0] rptr_sync1_bin;
logic [PTR_W-1:0] raddr;

logic [DATA_W-1:0] mem [2 ** ADDR_W];

//------------------------------------------------------------------------------
// Write side
//------------------------------------------------------------------------------
assign wr = wen & ~wfull;
assign wptr_next = wr ? gray2bin(wptr) + 1'b1 : gray2bin(wptr);

// write pointer is stored in the gray code
always_ff @(posedge wclk) begin
    if (wrst)
        wptr <= '0;
    else
        wptr <= bin2gray(wptr_next);
end
assign waddr = gray2bin(wptr);

// read pointer is also in the gray code - so it can be syncronized easily
always_ff @(posedge wclk) begin
    if (wrst) begin
        rptr_sync0 <= '0;
        rptr_sync1 <= '0;
    end else begin
        rptr_sync0 <= rptr;
        rptr_sync1 <= rptr_sync0;
    end
end

// do load logic in a binary form
assign rptr_sync1_bin = gray2bin(rptr_sync1);
always_ff @(posedge wclk) begin
    if (wrst)
        wload <= '0;
    else
        wload <= load(wptr_next, rptr_sync1_bin);
end
assign wfull = (wload == WORDS_TOTAL);

//------------------------------------------------------------------------------
// Read side
//------------------------------------------------------------------------------
assign rd = ren & ~rempty;
assign rptr_next = rd ? gray2bin(rptr) + 1'b1 : gray2bin(rptr);

// read pointer is stored in the gray code
always_ff @(posedge rclk) begin
    if (rrst)
        rptr <= 0;
    else
        rptr <= bin2gray(rptr_next);
end
assign raddr = gray2bin(rptr);

// write pointer is also in the gray code - so it can be syncronized easily
always_ff @(posedge rclk) begin
    if (rrst) begin
        wptr_sync0 <= '0;
        wptr_sync1 <= '0;
    end else begin
        wptr_sync0 <= wptr;
        wptr_sync1 <= wptr_sync0;
    end
end

always_ff @(posedge rclk) begin
    if (rrst)
        rvalid <= '0;
    else
        rvalid <= rd & ~rempty;
end

// do load logic in a binary form
assign wptr_sync1_bin = gray2bin(wptr_sync1);
always_ff @(posedge rclk) begin
    if (rrst)
        rload <= '0;
    else
        rload <= load(wptr_sync1_bin, rptr_next);
end
assign rempty = (rload == '0);

//------------------------------------------------------------------------------
// RAM module
//------------------------------------------------------------------------------
dpram #(
    .ADDR_W    (ADDR_W),
    .DATA_W    (DATA_W),
    .INIT_FILE ("")
) dpram (
    // Write interface
    .wclk  (wclk),
    .wdata (wdata),
    .waddr (waddr[ADDR_W-1:0]),
    .wr    (wr),
    // Read interface
    .rclk  (rclk),
    .rdata (rdata),
    .raddr (raddr[ADDR_W-1:0]),
    .rd    (rd)
);

endmodule
