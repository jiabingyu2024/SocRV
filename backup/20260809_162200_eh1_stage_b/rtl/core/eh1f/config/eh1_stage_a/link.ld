/*
 NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
 This is an automatically generated file by jiabingyu on Sun Aug  9 15:55:20 CST 2026

 cmd:    veer -target=high_perf -snapshot=eh1_stage_a -ahb_lite -iccm_enable=1 -iccm_size=128 -iccm_region=0 -iccm_offset=0x00000000 -dccm_enable=1 -dccm_size=64 -dccm_region=0 -dccm_offset=0x00020000 -icache_enable=0 -pic_size=32 -pic_total_int=8 -pic_region=0 -pic_offset=0x00030000 -fpga_optimize -set=reset_vec=0 

*/

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0;
  .text.init .  : { *(.text.init) }
   . = 0x00000000 ;
  .text . : { *(.text) }
  _end = .;
  . = 0xf0580000;
  .data.io .  : { *(.data.io) }
    . = 0x20000 ;
  .data  :  ALIGN(0x800) { *(.*data) *(.rodata*)}
  .bss :  {BSS_START = .; *(.*bss)}
  BSS_END = .;
  STACK = ALIGN(16) + 0x1000;
    . = 0xfffffff0; .iccm.ctl . : { LONG(0x00000000); LONG(0x0001ffff) }
    . = 0xfffffff8; .data.ctl : { LONG(0x20000); LONG(STACK) }
}

