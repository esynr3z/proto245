function automatic void new_randomized(int n, ref data_t data []);
    data = new[n];
    foreach (data[i])
        data[i] = $random();
endfunction

function automatic void push_to_queue(ref data_t queue [$], ref data_t data []);
    foreach (data[i])
        queue.push_front(data[i]);
endfunction

function automatic int compare_queues(ref data_t expected [$], ref data_t actual [$]);
    int err;
    if (expected.size() != actual.size()) begin
        $error("Length of the expected data is %0d, but length of actual data is %0d!",
               expected.size(), actual.size());
        err += 1;
    end else begin
        for (int i=0; i<expected.size(); i+=1) begin
            if (expected[i] !== actual[i]) begin
                $error("Expected data %0d is 0x%0x, but actual data is 0x%0x!",
                       i, expected[i], actual[i]);
                err += 1;
            end
        end
    end
    return err;
endfunction