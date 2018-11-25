# Makefile for GHDL threading simulator interface
#
# (c) 2011-2014 Martin Strubel <hackfin@section5.ch>
#
# See LICENSE.txt for usage policies
#

VERSION = 0.1dev

DEVICEFILE = ghdlsim.xml

GHDLEX = $(CURDIR)

ifdef DEVELOP
GHDLDIR = /data/src/ghdl/translate
GHDL = $(GHDLDIR)/ghdldrv/ghdl_gcc
GHDL_LIBPREFIX = $(GHDLDIR)/lib
else
GHDL ?= ghdl
endif

include platform.mk
-include config.mk

LIBDIR ?= ghdl

# USE_LEGACY = yes


# Not really needed for "sane" VHDL code. Use only for deprecated
# VDHL code. Some Xilinx simulation libraries might need it.
#
# GHDLFLAGS = --ieee=synopsys

HOST_CC ?= gcc

GHDLFLAGS = --workdir=$(LIBDIR) -P$(LIBDIR)

GHDL_LDFLAGS += $(GHDLFLAGS)

# Set to NETPP location, if you want to use specific NETPP dir
# It is better to put this into config.mk:
# NETPP = $(HOME)/src/netpp
# Run "make allnetpp" to fetch and build the source
#
NETPP ?= /usr/share/netpp
GENSOC ?= $(shell which gensoc)

NETPP_VER = netpp_src-0.40-svn321
NETPP_TAR = $(NETPP_VER).tgz 
NETPP_WEB = http://section5.ch/downloads/$(NETPP_TAR)
CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )
CONFIG_GENSOC = $(shell [ -e $(GENSOC) ] && echo y )
CURDIR = $(shell pwd)

WORK = $(LIBDIR)/work-obj93.cf

ifeq ($(CONFIG_NETPP),y)
VARIANT = -netpp
CFLAGS += -DCONFIG_NETPP
endif


LIBGHDLEX = libghdlex$(VARIANT)

LIBRARIES = $(LIBGHDLEX)$(DLLEXT) $(LIBDIR)/ghdlex-obj93.cf

$(LIBGHDLEX)$(DLLEXT):
	$(MAKE) -C src NETPP=$(NETPP) LIBSIM=$(LIBGHDLEX)

HOST_CFLAGS = -g -Wall -Isrc

NO_CLEANUP_DUTIES-y = 
NO_CLEANUP_DUTIES-$(CONFIG_NETPP) += $(NETPP)/common

DUTIES-y = 
DUTIES-$(CONFIG_NETPP) += simnetpp
DUTIES-$(CONFIG_NETPP_DISPLAY) += simfb
DUTIES-$(CONFIG_NETPP) += simram simboard

DUTIES-$(CONFIG_LINUX) += simpty

DUTIES = $(DUTIES-y)

LIBSLAVE = $(NETPP)/devices/libslave

GHDLEX_VHDL = $(wildcard hdl/*.vhdl)

ifdef USE_LEGACY
GHDLEX_VHDL += libfifo.vhdl
VHDLFILES = examples/fifo.vhdl 
endif

SOC_MODULES = localbus netppbus

SOC_VHDL = $(SOC_MODULES:%=ghdlex_%_decode.vhdl) ghdlex_iomap_pkg.vhdl


-include gensoc.mk

CONVERTED_VHDL-$(CONFIG_NETPP)+= libnetpp.vhdl
VHDLFILES-$(CONFIG_NETPP) += examples/netpp.vhdl 
VHDLFILES-$(CONFIG_NETPP_DISPLAY) += examples/fb.vhdl

VHDLFILES-$(CONFIG_NETPP) += examples/ram.vhdl
VHDLFILES-$(CONFIG_NETPP) += examples/board.vhdl


VHDLFILES += $(VHDLFILES-y)

# Pipe example obsolete, see improved pty.vhdl
VHDLFILES += examples/pty.vhdl

GHDLEX_VHDL += $(CONVERTED_VHDL-y)
GHDLEX_VHDL += $(GENERATED_VHDL-y)


all: $(NO_CLEANUP_DUTIES-y) $(DUTIES) 


DISTFILES = $(FILES:%=ghdlex/%)

SRCDISTFILES = $(DISTFILES) $(SRCFILES:%=ghdlex/%)

srcdist: $(GHDLEX_VHDL)
	cd ..; \
	tar cfz ghdlex-src-$(VERSION).tgz $(SRCDISTFILES)

dist:
	cd ..; \
	tar cfz ghdlex-sim-$(VERSION).tgz $(DISTFILES)

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


$(WORK): $(VHDLFILES) $(LIBDIR)/ghdlex-obj93.cf
	[ -e $(dir $@) ] || mkdir $(dir $@)
	$(GHDL) -i $(GHDLFLAGS) --work=work $(VHDLFILES)

show:
	@echo $(LIBDIR)/ghdlex-obj93.cf
	@echo Has gensoc: $(CONFIG_GENSOC)
	@echo Has netpp: $(CONFIG_NETPP)
	@echo $(VHDLFILES)


LDFLAGS = -Wl,-Lsrc -Wl,-lghdlex$(VARIANT)

ifeq ($(CONFIG_NETPP),y)
LDFLAGS-$(CONFIG_LINUX)   += -Wl,-L$(LIBSLAVE) -Wl,-lslave
LDFLAGS-$(CONFIG_MINGW32) += -Wl,-L$(LIBSLAVE)/$(CROSS)-Debug -Wl,-lslave
endif
 # Make sure libslave can use local_getroot():
LDFLAGS-$(CONFIG_LINUX)   += -Wl,-lpthread -Wl,-export-dynamic
LDFLAGS-$(CONFIG_MINGW32) += -Wl,-lws2_32

LDFLAGS += $(LDFLAGS-y)

# Rule to build simulation examples:
sim%: $(WORK) $(LIBRARIES) src/main.o
	$(GHDL) -m $(GHDL_LDFLAGS) $(LDFLAGS) $@
	$(GHDL) --bind $(GHDL_LDFLAGS) $(LDFLAGS) $@
	LINK_OBJS=`$(GHDL) --list-link $(GHDL_LDFLAGS) $(LDFLAGS) $@`; \
	$(CC) -o $@ src/main.o $$LINK_OBJS

# The ghdlex library for external use:
$(LIBDIR)/ghdlex-obj93.cf: $(GHDLEX_VHDL)
	[ -e $(LIBDIR) ] || mkdir $(LIBDIR)
	export GHDL_PREFIX=$(GHDL_LIBPREFIX); \
	$(GHDL) -i --work=ghdlex --workdir=$(LIBDIR) $(GHDLEX_VHDL)

clean:: clean_duties
	rm -fr $(LIBDIR)
	rm -f $(GENERATED_VHDL-y)
	rm -f $(WORK)
	$(MAKE) NETPP=$(CURDIR)/netpp clean_duties
	$(MAKE) -C src clean LIBSIM=$(LIBGHDLEX)

clean_duties:
	rm -f $(DUTIES) h2vhdl 
	rm -f func_decl.chdl func_body.chdl

FILES = LICENSE.txt README Makefile 
# No more support for VPI stuff:
# FILES += src/vpi_user.h
FILES = $(GHDLEX_VHDL) $(VHDLFILES)
SRCFILES += src/fifo.h src/ghpi.h src/netppwrap.h src/example.h
SRCFILES += src/bus.h
SRCFILES += ghdlsim.xml py/test.py

FILES += libnetpp.chdl h2vhdl.c

FILES += lib.mk platform.mk ghdlex.mk

SRCFILES += $(CSRCS) apidef.h apimacros.h threadaux.h registermap.h
SRCFILES += vpi_user.h vpiwrapper.c
SRCFILES += src/Makefile Doxyfile

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
	$(HOST_CC) -o $@ $(HOST_CFLAGS) -c $<
	
h2vhdl: h2vhdl.o
	$(HOST_CC) -o $@ $<
