task test_tx_flow_control(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];
    int words;
    int words1, words2;
    int offset;

    `START_TEST;
    // do series of write bursts to FIFO to check how FT buffer overflow is handled (txe deassertion)
    words1  = 16;
    offset = 0;
    repeat(5) begin
        $display("%0t: Send %0d words, receive %0d+%0d words", $time, words1, words1-offset, offset);
        fork
            begin
                new_randomized(words1, fifo_data);
                push_to_queue(expected_data, fifo_data);
                fifo_if.send(fifo_data);
            end
            begin
                ft245_if.recv(words1 - offset, ft245_data);
                push_to_queue(actual_data, ft245_data);
                if (offset) begin
                    ft245_if.recv(offset, ft245_data);
                    push_to_queue(actual_data, ft245_data);
                end
            end
        join
        err += compare_queues(expected_data, actual_data);
        expected_data.delete();
        actual_data.delete();
        offset += 1;
    end

    words1  = 16;
    words2  = 8;
    offset = 1;
    repeat(3) begin
        $display("%0t: Send %0d+%0d words, receive %0d+%0d words", $time,
                 words1, words2, words1-offset, words2+offset);
        fork
            begin
                new_randomized(words1, fifo_data);
                push_to_queue(expected_data, fifo_data);
                fifo_if.send(fifo_data);
                @(negedge ft245_if.txen);
                new_randomized(words2, fifo_data);
                push_to_queue(expected_data, fifo_data);
                fifo_if.send(fifo_data);
            end
            begin
                ft245_if.recv(words1-offset, ft245_data);
                push_to_queue(actual_data, ft245_data);
                ft245_if.recv(words2+offset, ft245_data);
                push_to_queue(actual_data, ft245_data);
            end
        join
        err += compare_queues(expected_data, actual_data);
        expected_data.delete();
        actual_data.delete();
        offset += 1;
    end
    `END_TEST;
endtask