
PLATFORM ?= $(shell uname)

ifeq ($(PLATFORM),Linux)
	CONFIG_LINUX = y
	DLLEXT = so
endif

ifeq ($(PLATFORM),mingw32)
	MASOCIST = $(HOME)/src/vhdl/masocist
	CONFIG_MINGW32 = y
	DLLEXT = dll
	include $(MASOCIST)/vendor/section5/mingw32_config.mk
	CC=$(CROSS_CC)
endif
