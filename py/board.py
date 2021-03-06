#!/bin/env/python

# Simple test access of netpp simulation server
#
# Run the board simulation 'simboard', then this script from the current
# working directory.
#
# (c) 2010-2018 Martin Strubel <hackfin@section5.ch>

import time
import netpp
from utils import *

SIMULATION_URL = "TCP:localhost:2010"

def test_blk(r, bufsize, throttle = 1, delay = 0.01):
	t = ""
	l = 0
	fifo = getattr(r, ":simboard:nfifo(0):fifo:")
	r.SimThrottle.set(throttle)

	COUNT_WRAP = 0x0100

	n = bufsize / 2

	should = ""
	c = 0
	for i in range(n):
		should += chr((c >> 8) & 0xff) + chr(c & 0xff)
		c += 1
		if c == COUNT_WRAP:
			c = 0

	b = buffer(should)
	fifo.Buffer.set(b)

	a = netpp.Buffer(bufsize)

	print "buf size: %d bytes, reference size: %d" % (bufsize, len(should))

		
	retry = 0
	while l < bufsize:
		fill = fifo.InFill.get()
		print fill
		if fill >= bufsize:
			fifo.Buffer.get(a)
			# dump(a)
			t += str(a)
			l += len(a)
			retry = 0
		elif delay > 0.0:
			print "Polling... %.1f s (retry %d).." % (delay, retry)
			r.SimThrottle.set(0)
			time.sleep(delay)
			r.SimThrottle.set(throttle)
			retry += 1

		if retry > 10:
			print "Got nothing for 10 retries"
			break

	if len(t) > len(should):
		print "Truncated %d" % (len(t) - len(should))
		t = t[:len(should)]

	if should != t:
		if len(t) != len(should):
			print "Length mismatch"
		else:
			i = find_mismatch(should, t)
			print "Position", i
			dump(should[i:i+16])
			dump(t[i:i+16])
		f = open("dump.bin", "w")
		f.write(t)
		f.close()
	else:
		print "Buffer ok!"

def run_test(r):
	enable = r.Enable
	reset = r.Reset

	enable.set(0)
	reset.set(1)
	time.sleep(0.1)
	reset.set(0)

	enable.set(1)

	print "read n blocks, accelerated"
	for i in range(4):
		test_blk(r, 512, 1, 1.0)

	print "read n blocks, non-throttled"
	for i in range(4):
		test_blk(r, 512, 0, 0.0)

	return True

if __name__ == "__main__":
	dev = netpp.connect(SIMULATION_URL)
	r = dev.sync()
	run_test(r)
