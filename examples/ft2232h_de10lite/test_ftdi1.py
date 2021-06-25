#!/usr/bin/env python3

import ftdi1 as ft
from time import time, sleep

KiB = 1024
MiB = KiB * 1024


class FPGA:
    def __init__(self, serial, sync=True, vid=0x0403, pid=0x6010):
        self._vid = vid
        self._pid = pid
        self._serial = serial
        self._sync = sync

    def _err_wrap(self, ret):
        if ret < 0:  # prints last error message
            raise Exception("%s (%d)" % (ft.get_error_string(self._ctx), ret))
        else:
            return ret

    def __enter__(self):
        self._ctx = ft.new()
        self._err_wrap(ft.init(self._ctx))
        self._err_wrap(ft.usb_open_desc(self._ctx, self._vid, self._pid, None, self._serial))
        self._err_wrap(ft.set_bitmode(self._ctx, 0xff, ft.BITMODE_SYNCFF if self._sync else ft.BITMODE_RESET))
        self._err_wrap(ft.read_data_set_chunksize(self._ctx, 16 * KiB))
        self._err_wrap(ft.write_data_set_chunksize(self._ctx, 16 * KiB))
        return self

    def __exit__(self, type, value, traceback):
        self._err_wrap(ft.usb_close(self._ctx))
        ft.deinit(self._ctx)

    def write(self, data):
        bytes_wrote = self._err_wrap(ft.write_data(self._ctx, data))
        return bytes_wrote

    def read(self, n):
        bytes_read, data = ft.read_data(self._ctx, n)
        self._err_wrap(bytes_read)
        return (bytes_read, data)

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
        self._err_wrap(ft.tcioflush(self._ctx))
        self.write(self.__cmd(0xBEEF, total_bytes - 1))

        # Receive data
        chunks = []
        start_time = time()
        while total_bytes > 0:
            chunk_len, chunk = self.read(16 * KiB if total_bytes > 16 * KiB else total_bytes)
            if chunk_len == 0:
                break
            else:
                chunks.append(chunk[:chunk_len])
                total_bytes -= chunk_len
        exec_time = time() - start_time

        # Print statistics
        data = [b for chunk in chunks for b in chunk]  # flatten all chunks
        # print(data)
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
        self._err_wrap(ft.tcioflush(self._ctx))
        self.write(self.__cmd(0xCAFE, total_bytes - 1))

        # Transmit data
        result = 0
        start_time = time()
        self.write(data)
        while not result:
            result_len, result = self.read(1)
            if result_len == 0:
                result = 0
        exec_time = time() - start_time

        # Print statistics
        data_len_mb = total_bytes / MiB
        print("Wrote %.02f MiB (%d bytes) to FPGA in %f seconds (%.02f MiB/s)" %
              (data_len_mb, total_bytes, exec_time, data_len_mb / exec_time))

        # Verify data
        result = 0 if not result else result[0]
        print("Verify data: %s" % ('ok' if result == 0x42 else 'error'))


if __name__ == '__main__':
    with FPGA('FT3C8Z0A') as de10lite:
        de10lite.test_led()
        de10lite.test_read(100 * MiB)
        de10lite.test_write(100 * MiB)
