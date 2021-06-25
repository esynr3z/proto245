#!/usr/bin/env python3

from pylibftdi import Driver, Device
from time import time, sleep

KiB = 1024
MiB = KiB * 1024


class FPGA(Device):
    def __init__(self, ftdi_serial, fifo245_mode):
        super().__init__(device_id=ftdi_serial, mode='b',
                         lazy_open=True, interface_select=1)
        self.fifo245_mode = fifo245_mode

    def __enter__(self):
        super().open()
        self.ftdi_fn.ftdi_set_bitmode(0, 0x40 if self.fifo245_mode == 'sync' else 0x00)
        self.flush()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        super().close()

    def __cmd(self, code, data):
        return ((0xAA << 56) | (code << 40) | (data << 8) | 0x55).to_bytes(8, 'little')

    def test_led(self):
        self.write(self.__cmd(0x1ED0, 1))
        sleep(2)
        self.write(self.__cmd(0x1ED0, 0))
        sleep(2)

    def test_read(self, total_bytes=1 * MiB):
        # Prepare data
        golden_data = [i % 256 for i in range(total_bytes)]

        # Start read test
        self.write(self.__cmd(0xBEEF, total_bytes - 1))

        # Receive data
        self.flush()
        start_time = time()
        data = self.read(total_bytes)
        exec_time = time() - start_time

        # Print statistics
        data = [b for b in data]
        data_len = len(data)
        data_len_mb = data_len / MiB
        print("Read %.02f MiB (%d bytes) from FPGA in %f seconds (%.02f MiB/s)" %
              (data_len_mb, data_len, exec_time, data_len_mb / exec_time))

        # Verify data
        print("Verify data: %s" % ('ok' if golden_data == data else 'error'))

    def test_write(self, total_bytes=1 * MiB):
        # Prepare data
        data = bytes(bytearray([i % 256 for i in range(total_bytes)]))

        # Start write test
        self.write(self.__cmd(0xCAFE, total_bytes - 1))

        # Transmit data
        self.flush()
        result = 0
        start_time = time()
        self.write(data)
        while not result:
            result = self.read(1)
        exec_time = time() - start_time

        # Print statistics
        data_len_mb = total_bytes / MiB
        print("Wrote %.02f MiB (%d bytes) to FPGA in %f seconds (%.02f MiB/s)" %
              (data_len_mb, total_bytes, exec_time, data_len_mb / exec_time))

        # Verify data
        result = 0 if not result else result[0]
        print("Verify data: %s" % ('ok' if result == 0x42 else 'error'))


if __name__ == "__main__":
    with FPGA(ftdi_serial='FT3C8Z0A', fifo245_mode='sync') as de10lite:
        de10lite.test_led()
        de10lite.test_read(100 * MiB)
        de10lite.test_write(100 * MiB)
