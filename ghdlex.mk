TOPDIR ?= .

RANLIB ?= ranlib

CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )

include $(GHDLEX)/src/project.mk
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

clean::
	$(MAKE) -C $(GHDLEX)/src clean

.PHONY: mysim
