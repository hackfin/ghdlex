#!/bin/env/python

# Simple test access of netpp simulation server
# (c) 2010-2018 Martin Strubel <hackfin@section5.ch>

import time
import netpp

SIMULATION_URL = "TCP:localhost:2010"


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


dev = netpp.connect(SIMULATION_URL)
r = dev.sync()
f = getattr(r, ':simboard:nfifo(0):fifo:')
fifo = f.Buffer
enable = r.Enable

seq = [
	0x12, 0x20, 0x40, 0x00,
]

buf = seq2buf(seq)

r.SimThrottle.set(0) # No slow down
fifo.set(buf)
time.sleep(0.1)
enable.set(1)

time.sleep(0.5)
a = fifo.get()
dump(a)
r.SimThrottle.set(1) # Slow down simulation when FIFO is idle
