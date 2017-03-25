TOPDIR ?= .

RANLIB ?= ranlib

CSRCS = helpers.c

CFLAGS += -fPIC
ifdef DEBUG
CFLAGS += -DDEBUG -g
endif

CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )

CSRCS-$(CONFIG_NETPP) += netpp.c framebuf.c ram.c fifo.c bus.c
CSRCS-$(CONFIG_NETPP) += handler.c 

CSRCS-$(CONFIG_MINGW32) += threadaux.c
CSRCS-$(CONFIG_LINUX)   += pipe.c

CSRCS += $(CSRCS-y)

GHDLEXSRCS = $(CSRCS:%.c=$(GHDLEX)/src/%.c)

SIMOBJS = $(GHDLEXSRCS:%.c=%.o)

PROPLIST ?= proplist.o

$(LIBMYSIM).so: $(SIMOBJS) $(PROPLIST)
	$(CC) -o $@ -shared $(SIMOBJS) $(PROPLIST)

$(LIBMYSIM).a: $(SIMOBJS) $(PROPLIST)
	$(AR) ruv $@ $(SIMOBJS) $(PROPLIST)
	$(RANLIB) $@


MYSIM_DUTIES = $(LIBMYSIM).so

mysim: $(MYSIM_DUTIES)

.PHONY: mysim
