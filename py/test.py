#!/bin/env/python

# Simple test access of netpp simulation server
#
# Run the board simulation 'simboard', then this script from the current
# working directory.
#
# (c) 2010-2018 Martin Strubel <hackfin@section5.ch>

import time
import netpp

SIMULATION_URL = "TCP:localhost:2010"

def dump(seq):
	c = 0
	for i in seq:
		print "%02x" % (ord(i)),
		c += 1
		if c == 16:
			c = 0
			print
	print

def find_mismatch(b0, b1):
	for i in range(len(b0)):
		if b0[i] != b1[i]:
			print "Mismatch from %d" % i,
			print "should be: %02x, is: %02x" % (ord(b0[i]), ord(b1[i]))
			break
	return i

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


dev = netpp.connect(SIMULATION_URL)

r = dev.sync()
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

fifo = getattr(r, ":simboard:nfifo(0):fifo:")

print 80 * "-"
print "Flush..."
while fifo.InFill.get() > 128:
	test_blk(r, 128, 1, 0.1)

# Let FIFO flood:

r.SimThrottle.set(0)
time.sleep(0.2)
r.SimThrottle.set(1)

print "See if more data coming..."
try:
	c = fifo.Buffer.get()
	print "Had left in buffer:", len(c)
except TypeError:
	print "Empty buffer"

