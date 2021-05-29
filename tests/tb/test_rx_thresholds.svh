task test_rx_thresholds(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];
    int words;
    int start_err;
    int stop_err;

    `START_TEST;
    words = RX_START_THRESHOLD + RX_START_THRESHOLD / 2;
    fork
        begin // send data
            new_randomized(words, ft245_data);
            push_to_queue(expected_data, ft245_data);
            ft245_if.send(ft245_data);
        end
        begin
            // check that reading stops when "BURST_SIZE" words were received
            @(posedge ft245_if.rdn);
            repeat(10) @(posedge ft245_if.clk);
            if (fifo_if.rxfifo_load != RX_BURST_SIZE) begin
                stop_err = 1;
                $error("RX_BURST_SIZE error!");
            end else $display("RX_BURST_SIZE ok!");
            // check that receiveng starts only if load counter <= threshold
            fifo_if.recv(RX_BURST_SIZE - RX_START_THRESHOLD, fifo_data);
            push_to_queue(actual_data, fifo_data);
            wait(!ft245_if.oen);
            if (fifo_if.rxfifo_load > RX_START_THRESHOLD) begin
                start_err = 1;
                $error("RX_START_THRESHOLD error!");
            end else $display("RX_START_THRESHOLD ok!");
            fifo_if.recv(words - (RX_BURST_SIZE - RX_START_THRESHOLD), fifo_data);
            push_to_queue(actual_data, fifo_data);
        end
    join
    err += start_err;
    err += stop_err;
    err += compare_queues(expected_data, actual_data);
    `END_TEST;
endtask