SPACE = $(null) $(null)
COMMA = ,
# Create comma separated list:
MODULE_LIST=$(subst $(SPACE),$(COMMA),$(SOC_MODULES))

$(SOC_VHDL):
	$(GENSOC) -o ghdlex -sT \
		--map-prefix=2 \
		--decoder=$(MODULE_LIST) $(DEVICEFILE)

GENERATED_VHDL-$(CONFIG_NETPP)= $(SOC_VHDL) 

