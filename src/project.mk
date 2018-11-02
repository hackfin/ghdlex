CSRCS = helpers.c

ifdef DEBUG
CFLAGS += -DDEBUG -g
endif

# Important flag for external static compilation, we don't want to
# use import library symbols...
CFLAGS-$(CONFIG_MINGW32) += -DMSVC_STATIC
CFLAGS-$(CONFIG_NETPP)   += -I$(NETPP)/include -I$(NETPP)/devices
CFLAGS-$(CONFIG_NETPP)   += -DUSE_NETPP
CFLAGS-$(CONFIG_LINUX)   += -fPIC
CFLAGS-$(CONFIG_LEGACY)  += -DSUPPORT_LEGACY_FIFO

CFLAGS += $(CFLAGS-y)

CSRCS-$(CONFIG_NETPP) += netpp.c ram.c fifo.c bus.c
CSRCS-$(CONFIG_NETPP) += handler.c 
CSRCS-$(CONFIG_NETPP_DISPLAY) += framebuf.c 

CSRCS-$(CONFIG_MINGW32) += threadaux.c
CSRCS-$(CONFIG_LINUX)   += pipe.c
CSRCS-$(CONFIG_MINGW32) += winpipe.c

CSRCS += $(CSRCS-y)

