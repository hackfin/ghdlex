TOPDIR ?= .

RANLIB ?= ranlib

CONFIG_NETPP = $(shell [ -e $(NETPP)/xml ] && echo y )

include $(GHDLEX)/src/project.mk
GHDLEXSRCS = $(CSRCS:%.c=$(GHDLEX)/src/%.c)

SIMOBJS = $(GHDLEXSRCS:%.c=%.o)

PROPLIST ?= proplist.o

$(LIBSIM).so: $(SIMOBJS) $(PROPLIST)
	$(CC) -o $@ -shared $(SIMOBJS) $(PROPLIST) -lpthread

$(LIBSIM).a: $(SIMOBJS) $(PROPLIST)
	$(AR) ruv $@ $(SIMOBJS) $(PROPLIST)
	$(RANLIB) $@


ifdef CONFIG_MINGW32
MYSIM_DUTIES = $(LIBSIM).a
else
MYSIM_DUTIES = $(LIBSIM).so
endif

mysim: $(MYSIM_DUTIES)

clean::
	$(MAKE) -C $(GHDLEX)/src clean

.PHONY: mysim
