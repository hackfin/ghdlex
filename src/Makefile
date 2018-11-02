# Rules to build ghdlex library objects:
#

DEVICEFILE = ../ghdlsim.xml

GHDLEX = ..

RANLIB ?= ranlib

CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )

include ../platform.mk

# Special case: Build static for mingw32 cross:
DUTIES-$(CONFIG_MINGW32) = $(LIBSIM).a
DUTIES-$(CONFIG_LINUX)  += $(LIBSIM).$(DLLEXT)
DUTIES-$(CONFIG_NETPP)  += netpp.vpi

all: $(DUTIES-y)

VPIOBJS = vpiwrapper.o
VPIOBJS += vpi_proplist.o vpi_netpp.o vpi_ram.o vpi_bus.o vpi_handler.o

include project.mk

OBJS = $(CSRCS:%.c=%.o)

ifeq ($(CONFIG_NETPP),y)
OBJS += proplist.o
endif

ifeq ($(CONFIG_NETPP),y)
include $(NETPP)/xml/prophandler.mk
endif

regprops.xml: $(DEVICEFILE) $(XSLT)/regwrap.xsl
	$(XP) -o $@  \
	--stringparam selectDevice ghdlsim \
	$(XSLT)/regwrap.xsl $<

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
	$(CC) -shared -o $@ $(VPIOBJS) -lpthread -L$(LIBSLAVE) -lslave

handler.c: registermap.h

$(LIBSIM).a: $(OBJS)
	$(AR) ruv $@ $(OBJS)
	$(RANLIB) $@

$(LIBSIM).so: $(OBJS)
	$(CC) -shared -o $@ $(OBJS) -lpthread

$(LIBSIM).dll: $(OBJS)
	$(CC) -shared -o $@ $(OBJS)

clean::
	rm -f *.o *.a $(DUTIES-y)


show-duties:
	@echo $(DUTIES-y)
