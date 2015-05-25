#!/usr/bin/env python

import sys
from datetime import datetime
import time
import array
import struct
import os

try:
    import serial
except:
    print "This tool needs PySerial, but it was not found"
    sys.exit(1)

import swapforth as sf

class TetheredJ1b(sf.TetheredFT900):
    def __init__(self, port):
        ser = serial.Serial(port, 115200, timeout=None, rtscts=0)
        self.ser = ser
        self.searchpath = ['.']
        self.log = open("log", "w")

    def boot(self, bootfile = None):
        ser = self.ser
        ser.setDTR(1)
        ser.setDTR(0)
        boot = array.array('I', [int(l, 16) for l in open(bootfile)])
        boot = boot[:0x3f80 / 4]    # remove bootloader itself (top 128 bytes)
        while boot[-1] == 0:        # remove any unused words
            boot = boot[:-1]
        boot = boot.tostring()
        ser.write(chr(27))
        print 'wrote 27'
        # print repr(ser.read(1))

        ser.write(struct.pack('I', len(boot)))
        ser.write(boot)
        print 'completed load of %d bytes' % len(boot)
        # print repr(ser.read(1))

if __name__ == '__main__':
    port = '/dev/ttyUSB0'
    image = None

    r = None

    args = sys.argv[1:]
    while args:
        a = args[0]
        if a.startswith('-i'):
            image = args[1]
            args = args[2:]
        elif a.startswith('-h'):
            port = args[1]
            args = args[2:]
        else:
            if not r:
                r = TetheredJ1b(port)
                r.boot(image)
            if a.startswith('-e'):
                print r.shellcmd(args[1])
                args = args[2:]
            else:
                try:
                    r.include(a)
                except sf.Bye:
                    pass
                args = args[1:]
    if not r:
        r = TetheredJ1b(port)
        r.boot(image)

    print repr(r.ser.read(1))
    # r.interactive_command(None)
    r.shell(False)
    # r.listen()
