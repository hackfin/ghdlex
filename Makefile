# Makefile for GHDL threading simulator interface
#
# (c) 2011-2014 Martin Strubel <hackfin@section5.ch>
#
# See LICENSE.txt for usage policies
#

VERSION = 0.1dev

DEVICEFILE = ghdlsim.xml

include platform.mk
-include config.mk

# USE_LEGACY = yes


ifeq ($(CONFIG_MINGW32),y)
# We can only use a static lib, because on win32, DLLs can not call
# back functions from executables that they are linked against.
LIBGHDLEX = src/libmysim.a
else
LIBGHDLEX = src/libmysim.so
endif

LIBRARIES = $(LIBGHDLEX) lib/ghdlex-obj93.cf

$(LIBGHDLEX):
	$(MAKE) -C src

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
NETPP ?= $(CURDIR)/netpp

NETPP_VER = netpp_src-0.40-svn321
NETPP_TAR = $(NETPP_VER).tgz 
NETPP_WEB = http://section5.ch/downloads/$(NETPP_TAR)
CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )
CURDIR = $(shell pwd)

WORK = work/work-obj93.cf

CFLAGS = -g -Wall -Isrc

NO_CLEANUP_DUTIES-y = 
NO_CLEANUP_DUTIES-$(CONFIG_NETPP) += $(NETPP)/common
NO_CLEANUP_DUTIES-$(CONFIG_NETPP) += $(NETPP)/include/devlib_error.h

DUTIES-y = 
DUTIES-$(CONFIG_NETPP) += simnetpp simfb
DUTIES-$(CONFIG_NETPP) += simram simboard

DUTIES-$(CONFIG_LINUX) += simpipe simpty
DUTIES-$(CONFIG_LINUX) += src/netpp.vpi 

DUTIES = $(DUTIES-y)

LIBSLAVE = $(NETPP)/devices/libslave


GHDLEX_VHDL = $(wildcard hdl/*.vhdl)

GENERATED_VHDL =  registermap_pkg.vhdl
GENERATED_VHDL += decode_tap_registers.vhdl
GENERATED_GHDLEX_VHDL += libnetpp.vhdl


ifdef USE_LEGACY
GHDLEX_VHDL += libfifo.vhdl
VHDLFILES = examples/fifo.vhdl 
endif

GHDLEX_VHDL += $(GENERATED_GHDLEX_VHDL)

ifdef NETPP
VHDLFILES += examples/netpp.vhdl 
VHDLFILES += examples/fb.vhdl
VHDLFILES += examples/ram.vhdl
VHDLFILES += examples/board.vhdl
VHDLFILES += $(GENERATED_VHDL)
endif
VHDLFILES += examples/pipe.vhdl
VHDLFILES += examples/pty.vhdl


all: $(NO_CLEANUP_DUTIES-y) $(DUTIES) 

src/netpp.vpi:
	$(MAKE) -C src netpp.vpi

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

$(LIBSLAVE): | netpp

$(LIBSLAVE)/libslave.so: $(LIBSLAVE) 
	[ -e $@ ] || $(MAKE) -C $<


ifeq ($(CONFIG_NETPP),y)
include $(NETPP)/xml/prophandler.mk
else
endif

libnetpp.vhdl: libnetpp.chdl func_decl.chdl func_body.chdl
	cpp -P -o $@ $<

func_decl.chdl func_body.chdl: h2vhdl
	./$< func


$(WORK): $(VHDLFILES) lib/ghdlex-obj93.cf
	[ -e work ] || mkdir work
	$(GHDL) -i $(GHDLFLAGS) $(VHDLFILES)


-include gensoc.mk

LDFLAGS = -Wl,-Lsrc -Wl,-lmysim

ifdef CONFIG_NETPP
LDFLAGS-$(CONFIG_LINUX)   += -Wl,-L$(LIBSLAVE) -Wl,-lslave
LDFLAGS-$(CONFIG_MINGW32) += -Wl,-L$(LIBSLAVE)/$(CROSS)-Debug -Wl,-lslave
endif
 # Make sure libslave can use local_getroot():
LDFLAGS-$(CONFIG_LINUX)   += -Wl,-lpthread -Wl,-export-dynamic
LDFLAGS-$(CONFIG_MINGW32) += -Wl,-lws2_32

LDFLAGS += $(LDFLAGS-y)

# Rule to build simulation examples:
sim%: $(WORK) $(LIBRARIES)
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@

# The ghdlex library for external use:
lib/ghdlex-obj93.cf: $(GHDLEX_VHDL)
	[ -e lib ] || mkdir lib
	export GHDL_PREFIX=$(GHDL_LIBPREFIX); \
	$(GHDL) -i --work=ghdlex --workdir=lib $(GHDLEX_VHDL)

clean::
	rm -fr lib
	rm -f $(GENERATED_VHDL)
	rm -f $(WORK)
	$(MAKE) NETPP=$(CURDIR)/netpp clean_duties
	$(MAKE) -C src clean

clean_duties:
	rm -f $(DUTIES) h2vhdl 
	rm -f func_decl.chdl func_body.chdl

FILES = $(VHDLFILES) $(GHDLEX_VHDL) Makefile LICENSE.txt README
FILES += src/fifo.h src/ghpi.h src/netppwrap.h src/example.h
# No more support for VPI stuff:
# FILES += src/vpi_user.h
FILES += src/bus.h
FILES += ghdlsim.xml py/test.py
FILES += lib.mk

FILES += libnetpp.chdl h2vhdl.c

FILES += lib.mk

include ghdlex.mk
SRCFILES += $(CSRCS) apidef.h apimacros.h threadaux.h registermap.h

# FILES += $(SRCFILES:%=src/%)

allnetpp: $(LIBSLAVE)/libslave.so
	$(MAKE) NETPP=$(CURDIR)/netpp

$(NETPP)/common: 
	ln -s $< $(NETPP)/share/netpp/common $@

thread.o: thread.c
	$(CC) -o $@ -c $(CFLAGS) $<


doc_apidef.h: src/apidef.h
	cpp -C -E -DRUN_CHEAD -DNO_MACRO_DOCS $< >$@

docs: doc_apidef.h libnetpp.vhdl Doxyfile
	doxygen

h2vhdl.o: h2vhdl.c src/apidef.h
	$(HOST_CC) -o $@ $(CFLAGS) -c $<
	
h2vhdl: h2vhdl.o
	$(HOST_CC) -o $@ $<
