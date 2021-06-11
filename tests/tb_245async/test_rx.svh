task test_rx(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];

    `START_TEST;
    fork
        begin
            new_randomized(8, ft245_data);
            push_to_queue(expected_data, ft245_data);
            ft245_if.send(ft245_data);
            #1us;
            new_randomized(4, ft245_data);
            push_to_queue(expected_data, ft245_data);
            ft245_if.send(ft245_data);
        end
        begin
            fifo_if.recv(4, fifo_data);
            push_to_queue(actual_data, fifo_data);
            fifo_if.recv(8, fifo_data);
            push_to_queue(actual_data, fifo_data);
        end
    join
    err += compare_queues(expected_data, actual_data);
    `END_TEST;
endtask