# Makefile for GHDL threading simulator interface
#
# (c) 2011,2012 Martin Strubel <hackfin@section5.ch>
#
# See LICENSE.txt for usage policies
#

VERSION = 0.04

CSRCS = pipe.c fifo.c thread.c helpers.c ram.c

DUTIES = simpipe simfifo simram netpp.vpi

PLATFORM = $(shell uname)

LIBGHDLEX = libmysim.so
# LIBGHDLEX = libmysim.a

# Not really needed for "sane" VHDL code. Use only for deprecated
# VDHL code. Some Xilinx simulation libraries might need it.
#
# GHDLFLAGS = --ieee=synopsys

# Set to NETPP location, if you want to use specific NETPP dir
NETPP = $(HOME)/src/netpp
# Run "make allnetpp" to fetch and build the source
#
NETPP_VER = netpp_src-0.31-svn315
NETPP_TAR = $(NETPP_VER).tgz 
NETPP_WEB = http://section5.ch/src/$(NETPP_TAR)
NETPP_EXISTS = $(shell [ -e $(NETPP)/xml ] && echo yes )
CURDIR = $(shell pwd)

CFLAGS = -g -Wall -fPIC

ifeq ($(PLATFORM),Linux)
LDFLAGS = -Wl,-export-dynamic # Make sure libslave can use local_getroot()
endif

ifeq ($(NETPP_EXISTS),yes)
	DUTIES += simnetpp simfb
	NETPP_DEPS = $(NETPP)/include/devlib_error.h registermap.h
	DEVICEFILE = ghdlsim.xml
	LIBSLAVE = $(NETPP)/devices/libslave
	CSRCS += proplist.c handler.c netpp.c framebuf.c
	CFLAGS += -I$(NETPP)/include -I$(NETPP)/devices
	CFLAGS += -DUSE_NETPP
ifeq ($(PLATFORM),Linux)
	LDFLAGS += -Wl,-L$(LIBSLAVE) -Wl,-lslave
endif
endif

ifeq ($(PLATFORM),Linux)
LDFLAGS += -Wl,-L. -Wl,-lmysim -Wl,-lpthread
endif

OBJS = $(CSRCS:%.c=%.o)

VHDL = $(HOME)/src/vhdl
VHDLFILES = txt_util.vhdl
VHDLFILES += libpipe.vhdl libfifo.vhdl
VHDLFILES += simfifo.vhdl 
ifdef NETPP
VHDLFILES += iomap_config.vhdl registermap_pkg.vhdl libnetpp.vhdl
VHDLFILES += simnetpp.vhdl 
VHDLFILES += simfb.vhdl
VHDLFILES += dpram16.vhdl
VHDLFILES += simram.vhdl
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

libmysim.so: $(OBJS)
	$(CC) -shared -o $@ $(OBJS)

work-obj93.cf: $(VHDLFILES)
	ghdl -a $(GHDLFLAGS) $(VHDLFILES)

registermap_pkg.vhdl: ghdlsim.xml vhdlregs.xsl
	$(XP) -o $@ --stringparam srcfile $< \
	vhdlregs.xsl $<

regprops.xml: ghdlsim.xml $(XSLT)/regwrap.xsl
	$(XP) -o $@ $(XSLT)/regwrap.xsl $<

simpipe: work-obj93.cf $(LIBGHDLEX)
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simfifo: work-obj93.cf $(LIBGHDLEX)
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simram: work-obj93.cf $(LIBGHDLEX)
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simnetpp: work-obj93.cf $(LIBGHDLEX)
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simfb: work-obj93.cf $(LIBGHDLEX)
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

clean::
	rm -f work-obj93.cf
	rm -f *.o *.a *.so
	rm -f simfifo
	$(MAKE) NETPP=$(CURDIR)/netpp clean_duties

clean_duties:
	rm -f $(DUTIES) h2vhdl

FILES = $(VHDLFILES) $(CSRCS) Makefile LICENSE.txt README
FILES += fifo.h ghpi.h
FILES += ghdlsim.xml test.py
FILES += libnetpp.chdl h2vhdl.c apidef.h apimacros.h

DISTFILES = $(FILES:%=ghdlex/%)

dist:
	cd ..; \
	tar cfz ghdlex-$(VERSION).tgz $(DISTFILES)

# netpp unpack rule:

netpp:
	wget $(NETPP_WEB)
	tar xfz $(NETPP_TAR)

$(LIBSLAVE)/libslave.a: netpp
	$(MAKE) -C $<

allnetpp: $(LIBSLAVE)/libslave.a
	$(MAKE) NETPP=$(CURDIR)/netpp

VPIOBJS = vpiwrapper.o vpiproplist.o vpihandler.o vpinetpp.o

vpiwrapper.o: vpiwrapper.c
	$(CC) -o $@ -c -fPIC $(CFLAGS) $<

vpihandler.o: vpihandler.c
	$(CC) -o $@ -c -fPIC $(CFLAGS) $<

vpi%.o: %.c
	$(CC) -o $@ -c -fPIC $(CFLAGS) $<

thread.o: thread.c
	$(CC) -o $@ -c -fPIC $(CFLAGS) $<

# Only with netpp > v0.4
netpp.vpi: $(VPIOBJS)
	$(CC) --shared -o $@ $(VPIOBJS) -lpthread

doc_apidef.h: apidef.h
	cpp -C -E -DRUN_CHEAD $< >$@

registermap.h: $(DEVICEFILE)
	$(XP) -o $@ $(XSLT)/reg8051.xsl $(DEVICEFILE)

docs: doc_apidef.h Doxyfile
	doxygen

h2vhdl.o: h2vhdl.c apidef.h
	$(CC) -o $@ $(CFLAGS) -c $<
	
h2vhdl: h2vhdl.o
	$(CC) -o $@ $<
