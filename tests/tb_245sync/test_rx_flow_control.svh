task test_rx_flow_control(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];
    int words;
    int offset;

    `START_TEST;
    // do series of send bursts from FT with payload -7..+7 around RX FIFO size
    // to check how FT buffer empty event (rxf deassertion) and RX FIFO full event work
    words = RX_FIFO_SIZE - 7;
    repeat(15) begin
        $display("%0t: Send %0d words", $time, words);
        fork
            begin
                new_randomized(words, ft245_data);
                push_to_queue(expected_data, ft245_data);
                ft245_if.send(ft245_data);
            end
            begin
                @(posedge ft245_if.rdn)
                fifo_if.recv(words, fifo_data);
                push_to_queue(actual_data, fifo_data);
            end
        join
        err += compare_queues(expected_data, actual_data);
        expected_data.delete();
        actual_data.delete();
        words += 1;
    end
    `END_TEST;
endtask