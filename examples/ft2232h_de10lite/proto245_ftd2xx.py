#!/usr/bin/env python3

import ftd2xx as ft
from time import time, sleep


class FPGA:
    def __init__(self, ftdi_serial=b'FT3C8Z0AA'):
        self.ftdev_serial = ftdi_serial

    def __enter__(self):
        try:
            ftdev_id = ft.listDevices().index(self.ftdev_serial)
        except ValueError:
            raise Exception("No board found!")
        self.ftdev = ft.open(ftdev_id)
        self.ftdev.resetDevice()
        self.ftdev.setBitMode(0xff, 0x40)  # set fifo sync mode
        self.ftdev.setTimeouts(10, 10)  # in ms
        self.ftdev.setUSBParameters(65536, 65536)  # set rx, tx buffer size in bytes
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.ftdev.close()

    def __cmd(self, code, data):
        return ((0xAA << 56) | (code << 40) | (data << 8) | 0x55).to_bytes(8, 'little')

    def test_led(self):
        self.ftdev.write(self.__cmd(0x1ED0, 1))
        sleep(2)
        self.ftdev.write(self.__cmd(0x1ED0, 0))
        sleep(2)

    def test_read(self, total_bytes=1 * 1024 * 1024):
        # Start read test
        self.ftdev.write(self.__cmd(0xBEEF, total_bytes))

        # Receive data
        chunks = []
        start_time = time()
        while total_bytes > 0:
            chunk = self.ftdev.read(65536)
            if not chunk:
                break
            chunks.append(chunk)
            total_bytes -= len(chunk)
        exec_time = time() - start_time

        # Print statistics
        data = [b for chunk in chunks for b in chunk]  # flatten all chunks
        data_len = len(data)
        data_len_mb = data_len / 1024 / 1024
        print("Read %.02f MB (%d bytes) from FPGA in %f seconds (%.02f MB/s)" %
              (data_len_mb, data_len, exec_time, data_len_mb / exec_time))

        # Verify data
        golden_data = [i % 256 for i in range(data_len)]
        print("Data is correct: %s" % (golden_data == data))


if __name__ == "__main__":
    with FPGA() as de10lite:
        de10lite.test_led()
        de10lite.test_read(100 * 1024 * 1024)
