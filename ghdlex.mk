TOPDIR ?= .

RANLIB ?= ranlib

CSRCS = helpers.c

CFLAGS += -fPIC

CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )

CSRCS-$(CONFIG_NETPP) += netpp.c framebuf.c ram.c fifo.c bus.c
CSRCS-$(CONFIG_NETPP) += handler.c 

CSRCS-$(CONFIG_MINGW32) += threadaux.c
CSRCS-$(CONFIG_LINUX)   += pipe.c

CSRCS += $(CSRCS-y)

GHDLEXSRCS = $(CSRCS:%.c=$(GHDLEX)/src/%.c)

SIMOBJS = $(GHDLEXSRCS:%.c=%.o)

$(LIBMYSIM).so: $(SIMOBJS) proplist.o
	$(CC) -o $@ -shared $(SIMOBJS) proplist.o

$(LIBMYSIM).a: $(SIMOBJS) proplist.o
	$(AR) ruv $@ $(SIMOBJS) proplist.o
	$(RANLIB) $@


MYSIM_DUTIES = $(LIBMYSIM).so

mysim: $(MYSIM_DUTIES)

.PHONY: mysim
