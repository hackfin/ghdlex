
PLATFORM ?= $(shell uname)


ifeq ($(PLATFORM),Linux)
	CONFIG_LINUX = y
	DLLEXT = so
endif

ifeq ($(PLATFORM),mingw32)
	CONFIG_MINGW32 = y
	DLLEXT = dll
endif
