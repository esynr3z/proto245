interface ft245_async_if #(
    parameter DATA_W = 8
)(
    input bit clk
);

logic              rxfn;
logic              txen;
logic [DATA_W-1:0] din;
logic [DATA_W-1:0] dout;
logic              rdn;
logic              wrn;

modport dut (
    input din, rxfn, txen,
    output dout, rdn, wrn
);

typedef logic [DATA_W-1:0] data_t;

data_t txbuf [$];
data_t rxbuf [$];
localparam DEFAULT_TXBUF_LIMIT = 0;
int txbuf_limit = DEFAULT_TXBUF_LIMIT;

task automatic send(ref data_t data []); // when host send data, it go to the receive buffer
    foreach (data[i])
        rxbuf.push_front(data[i]);
    wait(rxbuf.size() == 0);
    repeat(2) @(posedge clk);
endtask

task automatic recv(int n, ref data_t data []); // when host want to receive data, it reads transmit buffer
    if (txbuf.size() < n) begin
        txbuf_limit = n;
        wait(txbuf.size() == n);
        repeat(4) @(posedge clk);
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
    rxfn = 1'b1;
    din  = '0;
    forever begin: data_drv
        wait(rxbuf.size() != 0);
        do begin
            #49ns rxfn = 1'b0;
            @(negedge rdn);
            #14ns din = rxbuf.pop_back();
            @(posedge rdn);
            #14ns rxfn = 1'b1;
        end while (rxbuf.size() != 0);
    end
endtask

task serve_write;
    txen = 1'b0;
    forever begin: data_drv
        wait(txbuf.size() < txbuf_limit);
        #49ns txen = 1'b0;
        @(negedge wrn);
        txbuf.push_front(dout);
        #14ns txen = 1'b1;
    end
endtask

endinterface