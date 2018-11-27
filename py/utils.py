
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
