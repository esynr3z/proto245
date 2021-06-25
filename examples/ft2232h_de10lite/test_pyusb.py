#!/usr/bin/env python3

import usb.core
import usb.util
from time import time, sleep

KiB = 1024
MiB = KiB * 1024


class FPGA:
    def __init__(self, serial, sync=True, vid=0x0403, pid=0x6010):
        self._vid = vid
        self._pid = pid
        self._serial = serial
        self._sync = sync

    def __enter__(self):
        dev = usb.core.find(idVendor=self._vid, idProduct=self._pid)
        if dev is None or dev.serial_number != self._serial:
            raise Exception("Device was not found!")
        self._ft = dev
        if self._ft.is_kernel_driver_active(0):
            self._ft.detach_kernel_driver(0)
        usb.util.claim_interface(self._ft, 0)
        self._ft.ctrl_transfer(bmRequestType=0x40, bRequest=11, wValue=0x000140ff if self._sync else 0x000000ff)
        return self

    def __exit__(self, type, value, traceback):
        usb.util.release_interface(self._ft, 0)

    def write(self, data):
        self._ft.write(0x2, data)  # OUT EP

    def read(self, n):
        return self._ft.read(0x81, n, 100)  # IN EP

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
        chunks = []
        start_time = time()
        while total_bytes > 0:
            chunk = self.read(256 * KiB)
            chunk_len = len(chunk)
            if chunk_len == 0:
                break
            elif chunk_len > 2:  # skip if read modem status bytes only
                chunks.append(chunk)
                modem_bytes = ((chunk_len // 512) + (1 if chunk_len % 512 else 0)) * 2
                total_bytes -= (chunk_len - modem_bytes)
        exec_time = time() - start_time

        # Print statistics
        data = [b for chunk in chunks for b in chunk]  # flatten all chunks
        # strips the two modem status bytes transfered during every read
        data = [b for i, b in enumerate(data) if i % 512 not in [0, 1]]
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
        result = 0
        start_time = time()
        self.write(data)
        while not result:
            data = self.read(3)
            if len(data) > 2:
                result = data[2]
        exec_time = time() - start_time

        # Print statistics
        data_len_mb = total_bytes / MiB
        print("Wrote %.02f MiB (%d bytes) to FPGA in %f seconds (%.02f MiB/s)" %
              (data_len_mb, total_bytes, exec_time, data_len_mb / exec_time))

        # Verify data
        print("Verify data: %s" % ('ok' if result == 0x42 else 'error'))


if __name__ == '__main__':
    with FPGA('FT3C8Z0A') as de10lite:
        de10lite.test_led()
        de10lite.test_read(100 * MiB)
        de10lite.test_write(10 * MiB)
