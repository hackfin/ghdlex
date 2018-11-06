# Makefile auxiliary to create GHDLEX library

GHDLEX ?= $(CURDIR)
GHDL ?= ghdl

VHDL_STD_SUFFIX ?= 93

ifndef CONFIG_NETPP
CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )
endif

PREFIX ?= .

GHDLEX_VHDL_DIR = $(GHDLEX)/hdl

GHDLEX_VHDL =  \
	$(GHDLEX_VHDL_DIR)/libpipe.vhdl \
	$(GHDLEX_VHDL_DIR)/libvirtual.vhdl \
	$(GHDLEX_VHDL_DIR)/vbus.vhdl \
	$(GHDLEX_VHDL_DIR)/vram.vhdl \
	$(GHDLEX_VHDL_DIR)/vram_dclk.vhdl \
	$(GHDLEX_VHDL_DIR)/vram16.vhdl \
	$(GHDLEX_VHDL_DIR)/vfifo.vhdl \
	$(GHDLEX_VHDL_DIR)/vfx2fifo.vhdl \
	$(GHDLEX_VHDL_DIR)/iomap_config.vhdl \
	$(GHDLEX_VHDL_DIR)/txt_util.vhdl

# Default compatibility layer for opensource release
ifeq ($(CONFIG_NETPP),y)
GHDLEX_VHDL += $(GHDLEX)/libnetpp.vhdl $(GHDLEX)/ghdlex_iomap_pkg.vhdl
GHDLEX_VHDL += $(GHDLEX)/ghdlex_netppbus_decode.vhdl
endif

$(PREFIX)/ghdlex-obj$(VHDL_STD_SUFFIX).cf: $(GHDLEX_VHDL)
	[ -e $(PREFIX) ] || mkdir $(PREFIX)
	$(GHDL) -i --std=$(VHDL_STD) \
		--workdir=$(PREFIX) --work=ghdlex $(GHDLEX_VHDL)

all: $(PREFIX)/ghdlex-obj$(VHDL_STD_SUFFIX).cf

DUTIES += $(PREFIX)/ghdlex-obj$(VHDL_STD_SUFFIX).cf
