# Example to test virtual bus
#


import netpp
from utils import *
import sys

SIMULATION_URL = "TCP:localhost:2010"

dev = netpp.connect(SIMULATION_URL)
r = dev.sync()
bus = r.TAP


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
r.SimThrottle.set(0) # Turn off Throttle
a = r.SimThrottle.get() # Dummy read to make sure the SimThrottle/off is
# effective before we continue

# Dump the first 8 addresses:
for i in range(8):
	bus.Addr.set(i)
	print "Data [%d]: %08x" % (i, bus.Data.get() & 0xffffffff)

r.SimThrottle.set(1) # Resume Throttle
a = r.SimThrottle.get() # Dummy read to make sure the SimThrottle/off is


# The local bus can only be accessed directly, no netpp properties
# map to it.
r.localbus.Addr.set(0)
magic = r.localbus.Data.get()
if magic !=  0xbaadf00d:
	print "WARNING: Unsigned integer return. FIXME (Python API)."

if magic & 0xffffffff !=  0xbaadf00d:
	print hex(magic)
	raise ValueError, "Failed to read magic from local bus"



