# MINGW32=1

NETPP = $(HOME)/src/netpp
GENSOC = $(HOME)/src/vhdl/gensoc

ifdef CONFIG_MINGW32
	EXE = .exe
	CROSS = i586-mingw32msvc
	PLATFORM = mingw32
	TOOLCHAIN_BUILD_ROOT = /media/scratch/build/toolchain
	BUILD = $(TOOLCHAIN_BUILD_ROOT)/$(CROSS)-ghdl
	BOOTSTRAP = $(TOOLCHAIN_BUILD_ROOT)/$(CROSS)-boot
	CROSS_BIN = $(BOOTSTRAP)/usr/bin
	# Important: trailing /
	GHDL_LIBPREFIX = $(BUILD)/usr/lib/gcc/$(CROSS)/4.8.2/vhdl/lib/
	GHDL_PREFIX = $(GHDL_LIBPREFIX)

	GHDL = $(BUILD)/usr/bin/$(CROSS)-ghdl

	CC = $(CROSS)-gcc
	RANLIB = $(CROSS)-ranlib

	# 	--LD=$(BOOTSTRAP)/usr/bin/i586-mingw32msvc-gcc

	GHDL_LDFLAGS += \
		--GHDL1=$(BUILD)/usr/libexec/gcc/i586-mingw32msvc/4.8.2/ghdl1 \
		--AS=/usr/bin/i586-mingw32msvc-as \
		--LD=/usr/bin/i586-mingw32msvc-gcc
		# Fails with undefined reference to `__dyn_tls_init_callback'
		# --AS=$(CROSS_BIN)/i586-mingw32msvc-as \
		# --LD=$(CROSS_BIN)/i586-mingw32msvc-gcc


	GHDL_LDFLAGS += -Wl,-L$(BOOTSTRAP)/usr/lib/
	GHDL_LDFLAGS += -Wl,-L$(BOOTSTRAP)/usr/lib/gcc/i586-mingw32msvc/4.8.2


	# For some preinstalled libs:
	GHDL_LDFLAGS += -Wl,-L/usr/i586-mingw32msvc/lib
else
endif

.EXPORT_ALL_VARIABLES: 

