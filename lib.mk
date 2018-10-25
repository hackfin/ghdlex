# Makefile auxiliary to create GHDLEX library

GHDLEX ?= $(CURDIR)
GHDL ?= ghdl

VHDL_STD_SUFFIX ?= 93

PREFIX ?= .

GHDLEX_VHDL_DIR = $(GHDLEX)/hdl

GHDLEX_VHDL =  \
	$(GHDLEX)/libnetpp.vhdl \
	$(GHDLEX)/registermap_pkg.vhdl \
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

$(PREFIX)/ghdlex-obj$(VHDL_STD_SUFFIX).cf: $(GHDLEX_VHDL)
	[ -e $(PREFIX) ] || mkdir $(PREFIX)
	$(GHDL) -i --std=$(VHDL_STD) \
		--workdir=$(PREFIX) --work=ghdlex $(GHDLEX_VHDL)

all: $(PREFIX)/ghdlex-obj$(VHDL_STD_SUFFIX).cf

DUTIES += $(PREFIX)/ghdlex-obj$(VHDL_STD_SUFFIX).cf
