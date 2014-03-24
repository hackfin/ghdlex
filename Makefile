# Makefile for GHDL threading simulator interface
#
# (c) 2011-2014 Martin Strubel <hackfin@section5.ch>
#
# See LICENSE.txt for usage policies
#

VERSION = 0.050develop



CSRCS = helpers.c ram.c fifo.c thread.c 

# DUTIES = simfifo simram simboard simfb simnetpp
DUTIES = simram simboard simfb simnetpp
DUTIES += regmap.vhdl

-include config.mk

# USE_LEGACY = yes

PLATFORM ?= $(shell uname)

ifeq ($(PLATFORM),mingw32)
# We can only use a static lib, because on win32, DLLs can not call
# back functions from executables that they are linked against.
LIBGHDLEX = libmysim.a
else
LIBGHDLEX = libmysim.so
endif

LIBRARIES = $(LIBGHDLEX) lib/ghdlex-obj93.cf



# Not really needed for "sane" VHDL code. Use only for deprecated
# VDHL code. Some Xilinx simulation libraries might need it.
#
# GHDLFLAGS = --ieee=synopsys

ifdef DEVELOP
GHDLDIR = /data/src/ghdl/translate
GHDL = $(GHDLDIR)/ghdldrv/ghdl_gcc
GHDL_LIBPREFIX = $(GHDLDIR)/lib
else
GHDL ?= ghdl
endif

HOST_CC ?= gcc
RANLIB ?= ranlib

GHDLFLAGS = --workdir=work -Plib

GHDL_LDFLAGS += $(GHDLFLAGS)

# GHDL_PREFIX = $(HOME)/build/ghdl/debian/ghdl
# GHDL_LIBPREFIX = $(GHDL_PREFIX)/usr/lib/gcc/x86_64-unknown-linux-gnu/4.7.2/vhdl/lib/

# ACTIVATE THIS when compiling with another GHDL
XGHDL = $(GHDL_PREFIX)/usr/bin/ghdl
XGHDLFLAGS = --work=work -Plib --PREFIX=$(GHDL_PREFIX) \
	--GHDL1=$(GHDL_PREFIX)/usr/libexec/gcc/x86_64-unknown-linux-gnu/4.7.2/ghdl1 \
	--PREFIX=$(GHDL_LIBPREFIX)

# Set to NETPP location, if you want to use specific NETPP dir
# It is better to put this into config.mk:
# NETPP = $(HOME)/src/netpp
# Run "make allnetpp" to fetch and build the source
#
NETPP_VER = netpp-0.40-svn320
NETPP_TAR = $(NETPP_VER).tgz 
NETPP_WEB = http://section5.ch/customer/head/$(NETPP_TAR)
NETPP_EXISTS = $(shell [ -e $(NETPP)/xml ] && echo yes )
CURDIR = $(shell pwd)

WORK = work/work-obj93.cf

CFLAGS = -g -Wall 

ifeq ($(PLATFORM),Linux)
DUTIES += simpipe netpp.vpi 
CFLAGS += -fPIC
LDFLAGS = -Wl,-export-dynamic # Make sure libslave can use local_getroot()
endif

ifndef NETPP
NETPP = $(CURDIR)/netpp
endif

LIBSLAVE = $(NETPP)/devices/libslave

LDFLAGS += -Wl,-L. -Wl,-lmysim

ifeq ($(NETPP_EXISTS),yes)
	DUTIES += simnetpp simfb
	NETPP_DEPS = $(NETPP)/common \
		$(NETPP)/include/devlib_error.h registermap.h
	DEVICEFILE = ghdlsim.xml
	CSRCS += proplist.c netpp.c framebuf.c
	CSRCS += handler.c 
	CFLAGS += -I$(NETPP)/include -I$(NETPP)/devices
	CFLAGS += -DUSE_NETPP
ifeq ($(PLATFORM),Linux)
	LDFLAGS += -Wl,-L$(LIBSLAVE) -Wl,-lslave
endif
ifeq ($(PLATFORM),mingw32)
	LDFLAGS += -Wl,-L$(LIBSLAVE)/$(CROSS)-Debug -Wl,-lslave
endif
endif


ifeq ($(PLATFORM),Linux)
LDFLAGS += -Wl,-lpthread
endif

ifeq ($(PLATFORM),mingw32)
	CSRCS += threadaux.c
	CFLAGS += -DMSVC_STATIC
	LDFLAGS += -Wl,-lws2_32
else
	CSRCS += pipe.c
endif

# DEPRECATED:
ifdef USE_LEGACY
CFLAGS += -DSUPPORT_LEGACY_FIFO
endif

OBJS = $(CSRCS:%.c=%.o)

GHDLEX_VHDL = \
	libvirtual.vhdl \
	libnetpp.vhdl \
	libpipe.vhdl \
	txt_util.vhdl \
	vbus.vhdl \
	vfifo.vhdl \
	dpram16.vhdl \
	vfx2fifo.vhdl \
	iomap_config.vhdl \
	registermap_pkg.vhdl \
	regmap.vhdl

ifdef USE_LEGACY
GHDLEX_VHDL += libfifo.vhdl
endif

VHDLFILES = simfifo.vhdl 
ifdef NETPP
VHDLFILES += simnetpp.vhdl 
VHDLFILES += simfb.vhdl
VHDLFILES += simram.vhdl
VHDLFILES += simboard.vhdl
endif
VHDLFILES += simpipe.vhdl

all: $(NETPP_DEPS) $(DUTIES) 

ifeq ($(NETPP_EXISTS),yes)
include $(NETPP)/xml/prophandler.mk
endif

libnetpp.vhdl: libnetpp.chdl func_decl.chdl func_body.chdl
	cpp -P -o $@ $<

func_decl.chdl: h2vhdl
	./$< func

libmysim.a: $(OBJS)
	$(AR) ruv $@ $(OBJS)
	$(RANLIB) $@

libmysim.so: $(OBJS)
	$(CC) -shared -o $@ $(OBJS) -lpthread

$(WORK): $(VHDLFILES) lib/ghdlex-obj93.cf
	[ -e work ] || mkdir work
	$(GHDL) -i $(GHDLFLAGS) $(VHDLFILES)

registermap_pkg.vhdl: ghdlsim.xml vhdlregs.xsl
	$(XP) -o $@ --stringparam srcfile $< \
	--param msb 7 \
	--param dwidth 32 \
	--param output_decoder 1 \
	vhdlregs.xsl $<

regprops.xml: ghdlsim.xml $(XSLT)/regwrap.xsl
	$(XP) -o $@ $(XSLT)/regwrap.xsl $<

simpipe: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@

simfifo: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@

simram: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@

simboard: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@

simnetpp: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@

simfb: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@


# The ghdlex library for external use:
lib/ghdlex-obj93.cf: $(GHDLEX_VHDL)
	[ -e lib ] || mkdir lib
	export GHDL_PREFIX=$(GHDL_LIBPREFIX); \
	$(GHDL) -i --work=ghdlex --workdir=lib $(GHDLEX_VHDL)

clean::
	rm -fr lib
	rm -f $(WORK)
	rm -f *.o *.a *.so
	$(MAKE) NETPP=$(CURDIR)/netpp clean_duties

clean_duties:
	rm -f $(DUTIES) h2vhdl

FILES = $(VHDLFILES) $(GHDLEX_VHDL) $(CSRCS) Makefile LICENSE.txt README
FILES += fifo.h ghpi.h netppwrap.h example.h vpi_user.h bus.h
FILES += ghdlsim.xml test.py
FILES += libnetpp.chdl h2vhdl.c apidef.h apimacros.h
FILES += vhdlregs.xsl map.xsl
FILES += vpiwrapper.c threadaux.h threadaux.c
FILES += perio.xsl

DISTFILES = $(FILES:%=ghdlex/%)

dist: $(GHDLEX_VHDL)
	cd ..; \
	tar cfz ghdlex-$(VERSION).tgz $(DISTFILES)

# netpp unpack rule:

$(NETPP_TAR):
	wget $(NETPP_WEB)

netpp: $(NETPP_TAR)
	tar xfz $(NETPP_TAR)
	ln -s $(NETPP_VER) netpp

$(LIBSLAVE)/libslave.so: netpp $(LIBSLAVE) 
	[ -e $@ ] || $(MAKE) -C $<

allnetpp: $(LIBSLAVE)/libslave.so
	$(MAKE) NETPP=$(CURDIR)/netpp

$(NETPP)/common: 
	ln -s $< $(NETPP)/share/netpp/common $@

$(LIBSLAVE): $(NETPP)/devices/slave
	ln -s $< $@

VPIOBJS = vpiwrapper.o
VPIOBJS += vpi_proplist.o vpi_netpp.o vpi_ram.o

vpiwrapper.o: vpiwrapper.c
	$(CC) -o $@ -c $(CFLAGS) $<

vpihandler.o: handler.c
	$(CC) -o $@ -c $(CFLAGS) $<

vpi_%.o: %.c
	$(CC) -o $@ -c $(CFLAGS) $<

thread.o: thread.c
	$(CC) -o $@ -c $(CFLAGS) $<

# Only with netpp > v0.4
netpp.vpi: $(VPIOBJS)
	$(CC) --shared -o $@ $(VPIOBJS) -lpthread -L$(LIBSLAVE) -lslave

doc_apidef.h: apidef.h
	cpp -C -E -DRUN_CHEAD -DNO_MACRO_DOCS $< >$@

registermap.h: $(DEVICEFILE)
	$(XP) -o $@ $(XSLT)/reg8051.xsl $(DEVICEFILE)

regmap.vhdl: $(DEVICEFILE) perio.xsl
	$(XP) -o $@ --stringparam srcfile $< \
		--param msb 7 \
		--stringparam regmap tap_registers \
		--param dwidth 32 \
		--xinclude perio.xsl $<

docs: doc_apidef.h Doxyfile
	doxygen

h2vhdl.o: h2vhdl.c apidef.h
	$(HOST_CC) -o $@ $(CFLAGS) -c $<
	
h2vhdl: h2vhdl.o
	$(HOST_CC) -o $@ $<
