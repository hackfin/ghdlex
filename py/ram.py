import sys
sys.path.append("/home/strubi/src/netpp/python")
sys.path.append("/home/strubi/src/netpp/Debug")
import netpp

d = netpp.connect("TCP:localhost")

r = d.sync()

# We need to get the attribute manually,
# because it has a non-pythonish namespace id:
ram0 = getattr(r, ":simboard:ram0:")

b = ram0.get()
b[0] = chr(0xf0)
a = ram0.get()
ram0.set(b)
c = ram0.get()
if b != a:
	print "Not equal"
else:
	print "equal"
