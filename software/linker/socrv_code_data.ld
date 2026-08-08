OUTPUT_ARCH(riscv)
ENTRY(_start)

INCLUDE linker/memory.ldh

MEMORY
{
  CODE (rx)  : ORIGIN = SOCRV_CODE_ORIGIN, LENGTH = SOCRV_CODE_LENGTH
  DATA (rwx) : ORIGIN = SOCRV_DATA_ORIGIN, LENGTH = SOCRV_DATA_LENGTH
}

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.start))
    KEEP(*(.text.trap))
    *(.text .text.*)
    . = ALIGN(4);
    __code_end = .;
  } > CODE

  .data : ALIGN(4)
  {
    __data_start = .;
    *(.rodata .rodata.*)
    . = ALIGN(4);
    __rt_init_start = .;
    KEEP(*(SORT(.rti_fn.*)))
    __rt_init_end = .;
    . = ALIGN(4);
    __fsymtab_start = .;
    KEEP(*(FSymTab))
    __fsymtab_end = .;
    *(.data .data.*)
    *(.sdata .sdata.*)
    . = ALIGN(4);
    __data_end = .;
  } > DATA
  __data_load_start = LOADADDR(.data);

  .bss (NOLOAD) : ALIGN(4)
  {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > DATA

  . = ALIGN(16);
  __image_end = .;
  __heap_start = .;
  __stack_top = ORIGIN(DATA) + LENGTH(DATA);
  __stack_bottom = __stack_top - 8K;
  __heap_end = __stack_bottom;
  __global_pointer$ = __data_start + 0x800;

  PROVIDE(_data_start = __data_start);
  PROVIDE(_data_end = __data_end);
  PROVIDE(_bss_start = __bss_start);
  PROVIDE(_bss_end = __bss_end);
  PROVIDE(_heap_start = __heap_start);
  PROVIDE(_heap_end = __heap_end);
  PROVIDE(_stack_top = __stack_top);
  PROVIDE(_stack_bottom = __stack_bottom);
  PROVIDE(__rt_rvstack = __stack_top);

  ASSERT(__code_end <= ORIGIN(CODE) + LENGTH(CODE), "CODE region overflow")
  ASSERT(__heap_start <= __heap_end, "DATA image/heap overlaps reserved stack")
  ASSERT((__stack_top & 15) == 0, "stack top must be 16-byte aligned")
}
