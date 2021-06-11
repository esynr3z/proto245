#!/usr/bin/env python3

import ftd2xx as ft
from time import time, sleep

# Open and setup
try:
    dev_id = ft.listDevices().index(b'FT3C8Z0AA')
except ValueError:
    raise Exception("No board found!")
dev = ft.open(dev_id)
dev.resetDevice()
dev.setBitMode(0xff, 0x40)  # set fifo sync mode
dev.setTimeouts(10, 10)  # in ms
dev.setUSBParameters(65536, 65536)  # set rx, tx buffer size in bytes

# LED test
dev.write(0x001711ED.to_bytes(4, 'little'))
sleep(2)
dev.write(0x00ff11ED.to_bytes(4, 'little'))
sleep(2)

# Start read test
dev.write(0xbadc0ffe.to_bytes(4, 'little'))

# Capture the data
chunks = []
total_bytes = 100 * 1024 * 1024
start_time = time()
while total_bytes > 0:
    chunk = dev.read(65536)
    if not chunk:
        break
    chunks.append(chunk)
    total_bytes -= len(chunk)
exec_time = time() - start_time

# Print results
data = [b for chunk in chunks for b in chunk]  # flatten all chunks
data_len = len(data)
data_len_mb = data_len / 1024 / 1024
print("Read %.02f MB (%d bytes) in %f seconds (%.02f MB/s)" %
      (data_len_mb, data_len, exec_time, data_len_mb / exec_time))

# Close the connection
dev.close()
