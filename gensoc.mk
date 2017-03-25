DECODER_XSL = $(GENSOC)/iomap.xsl
VHDLREGS_XSL = $(GENSOC)/vhdlregs.xsl

# Style sheet for peripheral I/O map generation:

registermap_pkg.vhdl: ghdlsim.xml $(VHDLREGS_XSL)
	$(XP) -o $@ --stringparam srcfile $< \
		--param msb 7 \
		--param useMapPrefix 2 \
		--param dwidth 32 \
		--param output_decoder 1 \
	$(VHDLREGS_XSL) $<


decode_%.vhdl: $(DEVICEFILE) $(DECODER_XSL)
	$(XP) -o $@ --stringparam srcfile $< \
		--param resetUndefined 1 \
		--stringparam defaultvalue "0" \
		--param useMapPrefix 2 \
		--param useAck 0 \
		--param msb 7 \
		--stringparam regmap $(patsubst decode_%.vhdl,%,$@) \
		--param dwidth 32 \
		--xinclude $(DECODER_XSL) $<

XSLFILES = $(PERIO_XSL) $(VHDLPORT_XSL) $(SYSMAP_XSL)
XSLFILES += $(VHDLREGS_XSL) $(MAP_XSL)
