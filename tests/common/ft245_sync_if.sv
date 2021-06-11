interface ft245_sync_if #(
    parameter DATA_W = 32
)(
    input bit clk
);

logic              rxfn;
logic              txen;
logic [DATA_W-1:0] din;
logic [DATA_W-1:0] dout;
logic              rdn;
logic              wrn;
logic              oen;

modport dut (
    input din, rxfn, txen,
    output dout, rdn, wrn, oen
);

clocking drv @(posedge clk);
    default input #4ns output #4ns;
    input dout, rdn, wrn, oen;
    output din, rxfn, txen;
endclocking

typedef logic [DATA_W-1:0] data_t;

data_t txbuf [$];
data_t rxbuf [$];
localparam DEFAULT_TXBUF_LIMIT = 1024;
int txbuf_limit = DEFAULT_TXBUF_LIMIT;

task automatic send(ref data_t data []); // when host send data, it go to the receive buffer
    foreach (data[i])
        rxbuf.push_front(data[i]);
    wait(rxbuf.size() == 0);
    repeat(2) @(drv);
endtask

task automatic recv(int n, ref data_t data []); // when host want to receive data, it reads transmit buffer
    if (txbuf.size() < n) begin
        txbuf_limit = n;
        wait(txbuf.size() == n);
        repeat(4) @(drv);
    end
    data = new[n];
    foreach (data[i])
        data[i] = txbuf.pop_back();
    txbuf_limit = DEFAULT_TXBUF_LIMIT;
endtask

task serve;
    fork
        serve_read;
        serve_write;
    join
endtask

task serve_read;
    drv.rxfn <= 1'b1;
    drv.din  <= '0;
    forever begin: data_drv
        @(drv);
        if (rxbuf.size() != 0) begin
            drv.rxfn <= 1'b0;
            do begin
                @(negedge oen);
                din <= rxbuf.pop_back();
                wait(!drv.rdn);
                while(!drv.rdn) begin
                    if (rxbuf.size() == 0) break;
                    drv.din <= rxbuf.pop_back();
                    @(drv);
                end
            end while (rxbuf.size() != 0);
            drv.rxfn <= 1'b1;
        end
    end
endtask

task serve_write;
        forever begin: data_drv
            @(drv);
            if (!drv.wrn && (txbuf.size() < txbuf_limit)) begin
                txbuf.push_front(drv.dout);
            end
            drv.txen <= (txbuf_limit > 1) ? (txbuf.size() >= (txbuf_limit - 1)) : 1'b0;
        end
endtask

endinterface