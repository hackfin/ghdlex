# Rules to build ghdlex library objects:
#

DEVICEFILE = ../ghdlsim.xml

NETPP ?= ../netpp

RANLIB ?= ranlib

CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )

include ../platform.mk

all: netpp.vpi libmysim.so

VPIOBJS = vpiwrapper.o
VPIOBJS += vpi_proplist.o vpi_netpp.o vpi_ram.o vpi_bus.o vpi_handler.o

########################### CSRCS ##############################
CSRCS = helpers.c
CSRCS-$(CONFIG_NETPP) += netpp.c framebuf.c ram.c fifo.c bus.c
CSRCS-$(CONFIG_NETPP) += handler.c 
CSRCS-$(CONFIG_MINGW32) += threadaux.c
CSRCS-$(CONFIG_LINUX) += pipe.c

CSRCS += $(CSRCS-y)

########################### CFLAGS #############################

CFLAGS-$(CONFIG_NETPP)   += -I$(NETPP)/include -I$(NETPP)/devices
CFLAGS-$(CONFIG_NETPP)   += -DUSE_NETPP
CFLAGS-$(CONFIG_LINUX)   += -fPIC
CFLAGS-$(CONFIG_MINGW32) += -DMSVC_STATIC
CFLAGS-$(CONFIG_LEGACY)  += -DSUPPORT_LEGACY_FIFO

CFLAGS += $(CFLAGS-y)

OBJS = $(CSRCS:%.c=%.o) proplist.o

ifeq ($(CONFIG_NETPP),y)
include $(NETPP)/xml/prophandler.mk
endif

regprops.xml: $(DEVICEFILE) $(XSLT)/regwrap.xsl
	$(XP) -o $@ $(XSLT)/regwrap.xsl $<

registermap.h: $(DEVICEFILE)
	$(XP) -o $@ --stringparam srcfile $< \
	--param convertBitfields 1 \
	--param useMapPrefix 1 \
	--stringparam regprefix R_ \
	$(XSLT)/registermap.xsl $<

vpiwrapper.o: vpiwrapper.c
	$(CC) -o $@ -c $(CFLAGS) $<

vpi_%.o: %.c
	$(CC) -o $@ -c $(CFLAGS) $<

# Only with netpp > v0.4
netpp.vpi: $(VPIOBJS)
	$(CC) --shared -o $@ $(VPIOBJS) -lpthread -L$(LIBSLAVE) -lslave

handler.c: registermap.h

libmysim.a: $(OBJS)
	$(AR) ruv $@ $(OBJS)
	$(RANLIB) $@

libmysim.so: $(OBJS)
	$(CC) -shared -o $@ $(OBJS) -lpthread

clean::
	rm -f *.o *.a *.so

