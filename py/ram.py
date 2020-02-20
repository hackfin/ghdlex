import netpp
import struct

ENDIAN = ">"

def get_dword(buf, i):
	i *= 4
	a = buf[i:i+4]
	s = struct.unpack(ENDIAN  + "L", a)

	return s[0]

def get_hword(buf, i):
	i *= 2
	a = buf[i:i+2]
	s = struct.unpack(ENDIAN  + "H", a)

	return s[0]


def run_test(r):
	# We need to get the attribute manually,
	# because it has a non-pythonish namespace id:
	ram0 = getattr(r, ":simboard:ram0:")
	ram1 = getattr(r, ":simboard:ram1:wrapper:")
	ram2 = r.Shadow32bit

	ram0.Offset.set(0)
	ram1.Offset.set(0)
	ram2.Offset.set(0)

	retry = 5

	# We have a few retries

	while r.Break.get() == 0 and retry > 0:
		retry -= -1

	if r.Break.get() == 0:
		raise SystemError, "Simulation not ready"

	a = ram0.Buffer.get()
	b = ram1.Buffer.get()
	c = ram2.Buffer.get()

	w = get_dword(c, 1)

	if w == 0xdeadbeef:
		print("Correct big endian initialization of 32 bit RAM")
		retry = 0
	elif w == 0xefbeadde:
		raise ValueError, "Wrong (legacy) little endian initialization of 32 bit RAM"
	else:
		raise ValueError, "Init value mismatch. Maybe restart simulation?"


	wl = get_hword(a, 1)
	wh = get_hword(b, 1)

	if wh == 0xdead and wl == 0xbeef:
		print("RAM0 and RAM1 LO/HI contents match")
	else:
		raise ValueError, "RAM error"



	c[0] = 'c'
	c[1] = 'o'
	c[2] = 'd'
	c[3] = 'e'

	ram2.Buffer.set(c)
	c1 = ram2.Buffer.get()

	if c1 != c:
		raise ValueError, "RAM contents do not match"

	ram2.Offset.set(4)
	c2 = ram2.Buffer.get()

	if c2[0] != c[4]:
		raise ValueError, "Offset test failed"

	return True


if __name__ == "__main__":
	dev = netpp.connect("localhost:2010")
	r = dev.sync()

	run_test(r)
