OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  CODE (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  DATA (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.start))
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
  } > CODE

  .data : ALIGN(4)
  {
    _data_start = .;
    *(.data .data.*)
    . = ALIGN(4);
    _data_end = .;
  } > DATA

  .bss (NOLOAD) : ALIGN(4)
  {
    _bss_start = .;
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > DATA

  . = ALIGN(16);
  _heap_start = .;
  _stack_top = ORIGIN(DATA) + LENGTH(DATA);
  _stack_bottom = _stack_top - 8K;
  _heap_end = _stack_bottom;
  PROVIDE(__rt_rvstack = _stack_top);

  ASSERT(_heap_start <= _heap_end, "DATA region overlaps the reserved stack")
  ASSERT(SIZEOF(.text) <= LENGTH(CODE), "CODE region overflow")
}
