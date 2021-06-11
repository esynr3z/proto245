task test_tx(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];

    `START_TEST;
    new_randomized(6, fifo_data);
    push_to_queue(expected_data, fifo_data);
    fork
        fifo_if.send(fifo_data);
        ft245_if.recv(6, ft245_data);
    join
    push_to_queue(actual_data, ft245_data);
    err += compare_queues(expected_data, actual_data);
    expected_data.delete();
    actual_data.delete();

    new_randomized(24, fifo_data);
    push_to_queue(expected_data, fifo_data);
    fork
        fifo_if.send(fifo_data);
        begin
            ft245_if.recv(16, ft245_data);
            push_to_queue(actual_data, ft245_data);
            #1us;
            ft245_if.recv(8, ft245_data);
            push_to_queue(actual_data, ft245_data);
        end
    join
    err += compare_queues(expected_data, actual_data);
    `END_TEST;
endtask