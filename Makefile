# Caprice32 — Amstrad CPC standalone core for Retro-Go SD
#
#   make              — build + pack caprice32.bin
#   make docker       — same inside the published builder image
#   make host         — SDL desktop preview (limited; use firmware for full test)

PROJECT_KIND ?= core

CORE_NAME  := caprice32
CORE_ENTRY := app_main_amstrad

CAP32_DIR := external/caprice32-go/cap32
PORT_DIR  := src/porting/amstrad
INC_DIR   := src/inc/porting/amstrad

CORE_C_SOURCES := \
$(CAP32_DIR)/cap32.c \
$(CAP32_DIR)/crtc.c \
$(CAP32_DIR)/fdc.c \
$(CAP32_DIR)/kbdauto.c \
$(CAP32_DIR)/psg.c \
$(CAP32_DIR)/slots.c \
$(CAP32_DIR)/cap32_z80.c \
$(PORT_DIR)/main_amstrad.c \
$(PORT_DIR)/amstrad_i18n.c \
$(PORT_DIR)/amstrad_catalog.c \
$(PORT_DIR)/amstrad_format.c \
$(PORT_DIR)/amstrad_loader.c \
$(PORT_DIR)/amstrad_video8bpp.c

CORE_C_INCLUDES := \
-I$(CAP32_DIR) \
-I$(INC_DIR) \
-Isrc/lib/lzma

# TARGET_GNW: Caprice GNW port. Undef GNW_DISABLE_COMPRESSION so .cdk LZMA
# tracks inflate via the firmware ABI (see fdc.c).
CORE_C_DEFS := \
-DPROJECT_KIND_CORE=1 \
-DCOVERFLOW=1 \
-DCHEAT_CODES=1 \
-DMAX_CHEAT_CODES=13 \
-DTARGET_GNW \
-UGNW_DISABLE_COMPRESSION

CORE_LDLIBS := -lm

CORE_LDSCRIPT := caprice32_core.ld
CORE_EXTRA_SEGMENTS := itcm:core_itcm

GNW_CORE_SDK ?= sdk
BUILD_DIR ?= build/$(PROJECT_KIND)

# Prefer a newer Arm GNU Toolchain when present (GCC 13 emits a ~8% larger
# Z80 interpreter and was enough to lose the old headroom). Override with
# GCC_PATH=... on the command line, or use `make docker` (builder has 15.x).
ifeq ($(origin GCC_PATH),undefined)
  ifneq ($(wildcard /Applications/ArmGNUToolchain/14.2.rel1/arm-none-eabi/bin),)
    GCC_PATH := /Applications/ArmGNUToolchain/14.2.rel1/arm-none-eabi/bin
  endif
endif

PACKED_BIN  := caprice32.bin
PAD_LOGO    := src/assets/pad.bmp
HEADER_LOGO := src/assets/header.bmp

include $(GNW_CORE_SDK)/Makefile

# Hot emu paths: -O2 (speed). Z80 alone at -O2 is ~64 KiB — ITCM keeps only
# the hot sections (see caprice32_core.ld); rare DDCB/FDCB stay in RAM_EMU.
CAP32_HOT_CFLAGS := $(filter-out -Os,$(CFLAGS)) -O2
$(BUILD_DIR)/cap32_z80.o:     CFLAGS := $(CAP32_HOT_CFLAGS)
$(BUILD_DIR)/crtc.o:          CFLAGS := $(CAP32_HOT_CFLAGS)
$(BUILD_DIR)/cap32.o:         CFLAGS := $(CAP32_HOT_CFLAGS)
$(BUILD_DIR)/psg.o:           CFLAGS := $(CAP32_HOT_CFLAGS)
$(BUILD_DIR)/main_amstrad.o:  CFLAGS := $(CAP32_HOT_CFLAGS)

PACK_CORE := $(GNW_CORE_SDK)/tools/pack_core.py
CORE_VERSION ?= $(shell git describe --tags --dirty 2>/dev/null || echo NOTAG)

.PHONY: pack
pack: $(TARGET_BIN) $(BUILD_DIR)/caprice32_core_itcm.bin $(PAD_LOGO) $(HEADER_LOGO)
	$(V)$(ECHO) [ PACK CORE ] $(PACKED_BIN) version=$(CORE_VERSION)
	$(V)python3 $(PACK_CORE) \
		--elf $(TARGET_ELF) --bin $(TARGET_BIN) \
		--system-name "Amstrad CPC" --dirname amstrad \
		--extensions "dsk cdk" \
		--core-name "Caprice32" \
		--version "$(CORE_VERSION)" \
		--pad-logo $(PAD_LOGO) \
		--header-logo $(HEADER_LOGO) \
		--logo-invert \
		--segment itcm:__ITCM_CORE_START__:__CORE_ITCM_CODE_END__:__CORE_ITCM_BSS_END__:$(BUILD_DIR)/caprice32_core_itcm.bin \
		--out $(PACKED_BIN)

all: pack

clean::
	$(V)rm -f $(PACKED_BIN)

#######################################
# Docker (same image as firmware repo)
#######################################
.PHONY: docker docker_pull docker_shell

RELEASE_VERSION ?= v1.5
DOCKER_REPOSITORY ?= sylverb/retro-go-sd-builder
DOCKER_IMAGE ?= $(DOCKER_REPOSITORY):$(RELEASE_VERSION)

DOCKER_TTY_FLAG := $(shell if [ -t 0 ]; then echo -it; else echo; fi)
DOCKER_USER := $(shell id -u):$(shell id -g)
DOCKER_RUN := docker run --rm $(DOCKER_TTY_FLAG) \
	--user $(DOCKER_USER) \
	-v "$(CURDIR):/opt/workdir" \
	-w /opt/workdir \
	$(DOCKER_IMAGE)

docker:
	$(V)$(ECHO) "[ DOCKER ]" $(DOCKER_IMAGE) "PROJECT_KIND=$(PROJECT_KIND)"
	$(V)$(DOCKER_RUN) make --no-print-directory -j$$(nproc) PROJECT_KIND=$(PROJECT_KIND)

docker_pull:
	$(V)$(ECHO) "[ PULL ]" $(DOCKER_IMAGE)
	$(V)docker pull $(DOCKER_IMAGE)

docker_shell:
	$(DOCKER_RUN) bash

include host/Makefile.host

.PHONY: print-PROJECT_KIND print-PACKED_BIN print-SIDECARS print-RO_BIN print-CORE_NAME print-DOCKER_IMAGE \
	print-TARGET_ELF print-TARGET_MAP print-CORE_VERSION
print-PROJECT_KIND:
	@echo $(PROJECT_KIND)
print-PACKED_BIN:
	@echo $(PACKED_BIN)
# The shared stage_release.py asks every project for RO_BIN: the extra
# device file installed beside the packed binary. Empty here.
# Extra device files installed beside PACKED_BIN, space separated.
print-SIDECARS:
	@echo $(SIDECARS)
print-RO_BIN:
	@echo $(RO_BIN)
print-CORE_NAME:
	@echo $(CORE_NAME)
print-DOCKER_IMAGE:
	@echo $(DOCKER_IMAGE)
print-TARGET_ELF:
	@echo $(TARGET_ELF)
print-TARGET_MAP:
	@echo $(BUILD_DIR)/$(CORE_NAME)_core.map
print-CORE_VERSION:
	@echo $(CORE_VERSION)
