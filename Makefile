# Makefile for GHDL threading simulator interface
#
# (c) 2011 Martin Strubel <hackfin@section5.ch>
#
# See LICENSE.txt for usage policies
#

VERSION = 0.03eval


CSRCS = pipe.c fifo.c thread.c helpers.c

DUTIES = simfifo simpipe

# Not really needed for "sane" VHDL code. Use only for deprecated
# VDHL code. Some Xilinx simulation libraries might need it.
#
# GHDLFLAGS = --ieee=synopsys

# Set to NETPP location, if you want to use NETPP
NETPP = $(HOME)/src/netpp
# Run "make netpp_build" to fetch and build the source
#
NETPP_VER = netpp_src-0.31-svn315
NETPP_TAR = $(NETPP_VER).tgz 
NETPP_WEB = http://section5.ch/src/$(NETPP_TAR)
NETPP_EXISTS = $(shell [ -e $(NETPP)/xml ] && echo yes )

CFLAGS = -g -Wall

LDFLAGS = -Wl,-L. -Wl,-lmysim -Wl,-lpthread

ifeq ($(NETPP_EXISTS),yes)
	DUTIES += simnetpp simfb
	NETPP_DEPS = $(NETPP)/include/devlib_error.h
	DEVICEFILE = ghdlsim.xml
	LIBSLAVE = $(NETPP)/devices/libslave/Debug
	CSRCS += proplist.c handler.c netpp.c
	CFLAGS += -I$(NETPP)/include -I$(NETPP)/devices
	CFLAGS += -DUSE_NETPP
	LDFLAGS += -Wl,-L$(LIBSLAVE) -Wl,-lslave
endif

OBJS = $(CSRCS:%.c=%.o)

VHDL = $(HOME)/src/vhdl
VHDLFILES = txt_util.vhdl
VHDLFILES += registermap_pkg.vhdl
VHDLFILES += libpipe.vhdl libfifo.vhdl libnetpp.vhdl
VHDLFILES += simfifo.vhdl simnetpp.vhdl simfb.vhdl
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

work-obj93.cf: $(VHDLFILES)
	ghdl -a $(GHDLFLAGS) $(VHDLFILES)

registermap_pkg.vhdl: ghdlsim.xml $(XSLT)/vhdlpkg.xsl
	$(XP) -o $@ $(XSLT)/vhdlpkg.xsl $<

simpipe: work-obj93.cf libmysim.a
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simfifo: work-obj93.cf libmysim.a
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simnetpp: work-obj93.cf libmysim.a
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

simfb: work-obj93.cf libmysim.a
	ghdl -e $(GHDLFLAGS) $(LDFLAGS) $@

clean::
	rm -f work-obj93.cf
	rm -f *.o *.a
	rm -f simfifo
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
	# ln -s $(NETPP_VER) $@

doc_apidef.h: apidef.h
	cpp -C -E -DRUN_CHEAD $< >$@

docs: doc_apidef.h Doxyfile
	doxygen

netpp_build: netpp
	make -C $<

h2vhdl.o: h2vhdl.c apidef.h
	$(CC) -o $@ $(CFLAGS) -c $<
	
h2vhdl: h2vhdl.o
	$(CC) -o $@ $<
