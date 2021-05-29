task test_tx_thresholds(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];
    int words;
    int start_err;
    int stop_err;

    `START_TEST;
    words = TX_START_THRESHOLD + TX_START_THRESHOLD / 2;
    fork
        begin // write to fifo
            new_randomized(words, fifo_data);
            push_to_queue(expected_data, fifo_data);
            fifo_if.send(fifo_data);
        end
        begin
            // check that sending starts only if load counter >= threshold
            @(negedge ft245_if.wrn);
            if (fifo_if.txfifo_load < TX_START_THRESHOLD) begin
                start_err = 1;
                $error("TX_START_THRESHOLD error!");
            end else $display("TX_START_THRESHOLD ok!");
            // check that sending stops only when "BURST_SIZE" words were transmitted
            @(posedge ft245_if.wrn);
            repeat(5) @(posedge ft245_if.clk);
            if (fifo_if.txfifo_load != (words - TX_BURST_SIZE)) begin
                stop_err = 1;
                $error("TX_BURST_SIZE error!");
            end else $display("TX_BURST_SIZE ok!");
            // check that all other words were transmitted
            @(negedge ft245_if.wrn);
            @(posedge ft245_if.wrn);
            ft245_if.recv(words, ft245_data);
            push_to_queue(actual_data, ft245_data);
        end
    join
    err += start_err;
    err += stop_err;
    err += compare_queues(expected_data, actual_data);
    `END_TEST;
endtask