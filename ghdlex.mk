RANLIB ?= ranlib

CSRCS = helpers.c ram.c fifo.c bus.c

CFLAGS = -fPIC

NETPP_EXISTS = $(shell [ -e $(NETPP)/xml ] && echo yes )

ifeq ($(NETPP_EXISTS),yes)
	CSRCS += netpp.c framebuf.c
	CSRCS += handler.c 
endif

GHDLEXSRCS = $(CSRCS:%.c=$(GHDLEX)/src/%.c)

SIMOBJS = $(GHDLEXSRCS:%.c=%.o)

$(LIBMYSIM).so: $(SIMOBJS) proplist.o
	$(CC) -o $@ -shared $(SIMOBJS) proplist.o

$(LIBMYSIM).a: $(SIMOBJS) proplist.o
	$(AR) ruv $@ $(SIMOBJS) proplist.o
	$(RANLIB) $@

mysim: $(LIBMYSIM).so

.PHONY: mysim
