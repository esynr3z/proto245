task test_tx_simple(output int err);
    data_t expected_data [$];
    data_t actual_data [$];
    data_t ft245_data [];
    data_t fifo_data [];

    `START_TEST;
    // simple several writes to FT chip
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
        ft245_if.recv(24, ft245_data);
    join
    push_to_queue(actual_data, ft245_data);
    err += compare_queues(expected_data, actual_data);
    `END_TEST;
endtask