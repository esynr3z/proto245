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


def cmd(code, data):
    return ((0xAA << 56) | (code << 40) | (data << 8) | 0x55).to_bytes(8, 'little')


# LED test
dev.write(cmd(0x1ED0, 1))
sleep(2)
dev.write(cmd(0x1ED0, 0))
sleep(2)

# Start read test
total_bytes = 100 * 1024 * 1024
dev.write(cmd(0xBEEF, total_bytes))

# Capture the data
chunks = []
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
print("Read %.02f MB (%d bytes) from FPGA in %f seconds (%.02f MB/s)" %
      (data_len_mb, data_len, exec_time, data_len_mb / exec_time))

# Verify results
golden_data = [i % 256 for i in range(data_len)]
print("Data is correct: %s" % (golden_data == data))

# Close the connection
dev.close()
