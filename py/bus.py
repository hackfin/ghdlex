# Example to test virtual bus
#


import netpp
from utils import *
import sys

dev = netpp.connect("localhost")
r = dev.sync()


bus = getattr(r, ":simboard:netpp_vbus:")


#############################################################################
# Local bus

buf = netpp.Buffer(32)
r.localbus.Addr.set(0)

r.localbus.DataBurst.get(buf)
dump(buf)

a = bus.Data.get()

print "dumb method get:"
r.localbus.Addr.set(0)
b = r.localbus.DataBurst.get()
dump(b)
b = r.localbus.DataBurst.get()
dump(b)
b = r.localbus.DataBurst.get()
dump(b)

#############################################################################
# Global bus (accessible through properties)
r.TapThrottle.set(0) # Turn off Throttle
a = r.TapThrottle.get() # Dummy read to make sure the TapThrottle/off is
# effective before we continue


for i in range(7):
	bus.Addr.set(i)
	print "Data [%d]: %08x" % (i, bus.Data.get() & 0xffffffff)

r.TapThrottle.set(1) # Resume Throttle
a = r.TapThrottle.get() # Dummy read to make sure the TapThrottle/off is

# We know IDCode is at address 0:
bus.Addr.set(0x0)
idcode = bus.Data.get()

if idcode != r.IDCode.get():
	raise ValueError, "Failed to read IDcode from local bus"

bus.Addr.set(0x8) # EMUCTRL
bus.Data.set(0x1) # Emurequest bit



# The local bus can only be accessed directly, no netpp properties
# map to it.
r.localbus.Addr.set(0)
magic = r.localbus.Data.get()
if magic !=  0xbaadf00d:
	print "WARNING: Unsigned integer return. FIXME (Python API)."

if magic & 0xffffffff !=  0xbaadf00d:
	print hex(magic)
	raise ValueError, "Failed to read magic from local bus"



