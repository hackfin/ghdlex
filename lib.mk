# Makefile auxiliary to create GHDLEX library

GHDLEX ?= $(CURDIR)

GHDLEX_VHDL_DIR = $(GHDLEX)/hdl

GHDLEX_VHDL =  \
	$(GHDLEX)/libnetpp.vhdl \
	$(GHDLEX)/registermap_pkg.vhdl \
	$(GHDLEX_VHDL_DIR)/libvirtual.vhdl \
	$(GHDLEX_VHDL_DIR)/vbus.vhdl \
	$(GHDLEX_VHDL_DIR)/vram.vhdl \
	$(GHDLEX_VHDL_DIR)/vram16.vhdl \
	$(GHDLEX_VHDL_DIR)/vfifo.vhdl \
	$(GHDLEX_VHDL_DIR)/vfx2fifo.vhdl \
	$(GHDLEX_VHDL_DIR)/iomap_config.vhdl \
	$(GHDLEX_VHDL_DIR)/txt_util.vhdl

ghdlex-obj93.cf: $(GHDLEX_VHDL)
	ghdl -i --work=ghdlex $(GHDLEX_VHDL)

DUTIES += ghdlex-obj93.cf
