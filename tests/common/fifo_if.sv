interface fifo_if #(
    parameter DATA_W = 32,
    parameter TX_FIFO_SIZE = 4096,
    parameter RX_FIFO_SIZE = 4096
)(
    input bit clk
);

localparam TX_FIFO_LOAD_W = $clog2(TX_FIFO_SIZE) + 1;
localparam RX_FIFO_LOAD_W = $clog2(RX_FIFO_SIZE) + 1;

logic                      rxfifo_rd = 1'b0;
logic [DATA_W-1:0]         rxfifo_data;
logic                      rxfifo_valid;
logic                      rxfifo_empty;
logic [RX_FIFO_LOAD_W-1:0] rxfifo_load;
logic [DATA_W-1:0]         txfifo_data = '0;
logic                      txfifo_wr = 1'b0;
logic                      txfifo_full;
logic [TX_FIFO_LOAD_W-1:0] txfifo_load;

modport dut (
    input  rxfifo_rd,
    output rxfifo_data, rxfifo_valid, rxfifo_empty, rxfifo_load,
    input  txfifo_data, txfifo_wr,
    output txfifo_full, txfifo_load
);

clocking drv @(posedge clk);
    input  rxfifo_data, rxfifo_valid, rxfifo_empty, rxfifo_load;
    output rxfifo_rd;
    input  txfifo_full, txfifo_load;
    output txfifo_data, txfifo_wr;
endclocking

typedef logic [DATA_W-1:0] data_t;

task automatic send(ref data_t data []);
    foreach (data[i]) begin
        @(drv);
        if (drv.txfifo_full) begin
            wait(!drv.txfifo_full);
            @(drv);
        end
        drv.txfifo_wr   <= 1'b1;
        drv.txfifo_data <= data[i];
    end
    @(drv);
    drv.txfifo_wr   <= 1'b0;
    drv.txfifo_data <= 0;
endtask

task automatic recv(int n, ref data_t data []);
    data = new[n];
    fork
        begin : rd_drv
            wait(!drv.rxfifo_empty);
            @(drv);
            drv.rxfifo_rd <= 1'b1;
            foreach (data[i]) begin
                @(drv);
                if (drv.rxfifo_empty) begin
                    wait(!drv.rxfifo_empty);
                end
            end
            drv.rxfifo_rd <= 1'b0;
        end
        foreach (data[i]) begin : data_drv
            @(drv);
            if (!drv.rxfifo_valid) begin
                wait(drv.rxfifo_valid);
            end
            data[i] = drv.rxfifo_data;
        end
    join
    @(drv);
endtask

endinterface
