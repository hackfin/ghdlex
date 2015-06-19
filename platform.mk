
PLATFORM ?= $(shell uname)


ifeq ($(PLATFORM),Linux)
	CONFIG_LINUX = y
endif

ifeq ($(PLATFORM),mingw32)
	CONFIG_MINGW32 = y
endif
