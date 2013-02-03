#!/bin/env/python

# Simple test access of netpp simulation server

NETPP = "/home/strubi/src/netpp"

import sys
sys.path.append(NETPP + "/Debug")
sys.path.append(NETPP + "/python")

import time
import netpp

dev = netpp.connect("localhost")

r = dev.sync()

def seq2buf(seq):
	b = ""
	for i in seq:
		b += chr(i)
	
	return buffer(b)

def dump(seq):
	c = 0
	for i in seq:
		print "%02x" % (ord(i)),
		if c == 16:
			c = 0
			print
	print

f = r.Fifo
fifo = f.Buffer
enable = r.Enable

seq = [
	0x12, 0x20, 0x40, 0x00,
]

buf = seq2buf(seq)

r.Throttle.set(0) # No slow down
fifo.set(buf)
time.sleep(0.1)
enable.set(1)

time.sleep(0.5)
a = fifo.get()
dump(a)
r.Throttle.set(1) # Slow down simulation when FIFO is idle
