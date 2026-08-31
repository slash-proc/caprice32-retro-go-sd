/*
 * Caprice32 — hot interpreter cluster in ITCM, compiled -O2.
 *
 * Full z80 at -O2 is ~64 KiB and leaves no room for crtc_cycle (called
 * every wait_states). Keep the hot Z80 sections + CRTC + PSG + IN/OUT
 * together in ITCM; leave rare DDCB/FDCB prefixes and cold cap32 init
 * in RAM_EMU (occasional veneer only).
 */

INCLUDE gnw_ram_emu.ld
INCLUDE gnw_itcm_core.ld

MEMORY
{
  RAM_EMU (xrw) : ORIGIN = __RAM_EMU_START__, LENGTH = __RAM_EMU_LENGTH__
  ITCM    (xrw) : ORIGIN = __ITCM_CORE_START__, LENGTH = __ITCM_CORE_LENGTH__
}

SECTIONS
{
  .core_itcm __ITCM_CORE_START__ :
  {
    __CORE_ITCM_CODE_START__ = .;

    /* Z80 hot path (-O2). DDCB/FDCB + z80_init_tables stay in RAM_EMU. */
    build/core/cap32_z80.o(.text.cap32_z80_execute)
    build/core/cap32_z80.o(.text.z80_pfx_cb)
    build/core/cap32_z80.o(.text.z80_pfx_dd)
    build/core/cap32_z80.o(.text.z80_pfx_fd)
    build/core/cap32_z80.o(.text.z80_pfx_ed)

    /* Called every z80_wait_states / audio tick / port I/O. */
    build/core/crtc.o(.text*)
    build/core/psg.o(.text*)
    build/core/cap32.o(.text.z80_IN_handler)
    build/core/cap32.o(.text.z80_OUT_handler)

    . = ALIGN(4);
    __CORE_ITCM_CODE_END__ = .;
  } >ITCM AT>RAM_EMU

  __CORE_ITCM_BSS_END__ = __CORE_ITCM_CODE_END__;

  ASSERT(__CORE_ITCM_BSS_END__ <= __ITCM_CORE_START__ + __ITCM_CORE_LENGTH__,
         "Error: Caprice32 ITCM segment overflows 64 KiB ITCM")

  .core_entry __RAM_EMU_START__ :
  {
    KEEP(*(.core_entry))
    KEEP(*(.gw_core_bridge_probe))
    . = ALIGN(4);
    /* Remaining .text* (cold Z80 prefixes, rest of cap32, porting, …). */
    EXCLUDE_FILE(build/core/crtc.o build/core/psg.o) *(.text*)
    *(.rodata*)
    *(.glue_7)
    *(.glue_7t)

    . = ALIGN(4);
    __CORE_INIT_ARRAY_START__ = .;
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array*))
    __CORE_INIT_ARRAY_END__ = .;
  } >RAM_EMU

  .data :
  {
    *(.data*)
  } >RAM_EMU

  __CORE_CODE_END__ = .;

  .bss (NOLOAD) :
  {
    . = ALIGN(8);
    *(.bss*)
    *(COMMON)
    . = ALIGN(8);
  } >RAM_EMU

  __CORE_BSS_END__ = .;

  ASSERT(__CORE_BSS_END__ <= __RAM_EMU_END__,
         "Error: Caprice32 code+data+bss overflows RAM_EMU")

  __exidx_start = .;
  __exidx_end = .;

  /DISCARD/ :
  {
    *(.fini_array*)
    *(.preinit_array*)
    *(.ARM.exidx*)
    *(.ARM.extab*)
    *(.comment)
    *(.ARM.attributes)
  }
}
