OUTPUT_ARCH(riscv)
ENTRY(_start)

INCLUDE software/linker/memory.ldh

MEMORY
{
  CODE (rx)  : ORIGIN = SOCRV_CODE_ORIGIN, LENGTH = SOCRV_CODE_LENGTH
  DATA (rwx) : ORIGIN = SOCRV_DATA_ORIGIN, LENGTH = SOCRV_DATA_LENGTH
}

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.init))
    *(.text .text.*)
    . = ALIGN(4);
    __code_end = .;
  } > CODE

  /* ICCM is fetch-only; constants read by load instructions reside in DCCM. */
  .rodata : ALIGN(16)
  {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  } > DATA

  .data : ALIGN(16)
  {
    *(.data .data.*)
    *(.sdata .sdata.*)
    . = ALIGN(16);
    __data_end = .;
  } > DATA

  .bss (NOLOAD) : ALIGN(16)
  {
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(16);
    __bss_end = .;
  } > DATA

  ASSERT(__code_end <= ORIGIN(CODE) + LENGTH(CODE), "CODE region overflow")
  ASSERT(__bss_end <= ORIGIN(DATA) + LENGTH(DATA), "DATA region overflow")
}
