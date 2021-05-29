//-------------------------------------------------------------------
// Dual port RAM primitive
//-------------------------------------------------------------------
module dpram #(
    parameter ADDR_W    = 10, // Memory depth
    parameter DATA_W    = 8,  // Data width
    parameter INIT_FILE = ""  // Path to initial file
)(
    // Write interface
    input  logic              wclk,  // Write clock
    input  logic [DATA_W-1:0] wdata, // Write data
    input  logic [ADDR_W-1:0] waddr, // Write address
    input  logic              wr,    // Write operation enable
    // Read interface
    input  logic              rclk,  // Read clock
    output logic [DATA_W-1:0] rdata, // Read data
    input  logic [ADDR_W-1:0] raddr, // Read address
    input  logic              rd     // Read operation enable
);

// Memory array
logic [DATA_W-1:0] mem [2**ADDR_W-1:0];

// Init memory
initial begin
    if (INIT_FILE)
        $readmemh(INIT_FILE, mem);
end

// Write port
always_ff @(posedge wclk) begin
    if (wr)
        mem[waddr] <= wdata;
end

// Read port
always_ff @(posedge rclk) begin
    if (rd)
        rdata <= mem[raddr];
end

endmodule
