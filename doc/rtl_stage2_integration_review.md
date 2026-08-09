# EH1F TCM SoC Stage 2 integration review

Date: 2026-08-09

Status: **RTL integration contract reviewed; not yet ready for simulation.**

This review covers the active `rtl/filelist.f` design after the Stage A-E migration. It is a source-level integration review only. No RTL compilation, simulation, lint, timing analysis, bitstream generation, or board run is claimed here.

## Frozen target

- CPU ISA/ABI: `RV32IMF_Zicsr` / `ilp32f`; machine mode only; `misa.C=0`.
- Memory: 128 KiB ICCM at `0x0000_0000`, 64 KiB DCCM at `0x0002_0000`.
- Local MMIO: TIMER `0x1000_0000`, UART `0x1000_1000`, GPIO `0x1000_2000`, SYSCTRL `0x1000_3000`.
- Memory protection features deliberately absent: instruction cache, data cache, ECC/parity, AXI/AHB external-memory interface, DMA and functional PIC.
- Board target: `xc7k325tffg900-2`, 200 MHz differential input, generated 250 MHz SoC clock.
- Workload: RT-Thread plus CoreMark, default 10,000 iterations, performance target about 10 seconds and CoreMark/MHz greater than 4.

## Active RTL boundary

`rtl/filelist.f` selects `rtl/filelist_stage_e.f`. The filelist checker resolves 67 unique RTL sources. `soc_memory_map_pkg.sv` appears before its SoC and LSU consumers. Every RTL source currently under `rtl/` is listed once; no missing or duplicate path was reported.

The synthesizable external boundary is `soc_top`:

```text
inputs : core_clk, rst_n, uart_rx, gpio_in[15:0]
outputs: uart_tx, gpio_out[15:0], gpio_oe[15:0],
         test_status[31:0], test_code[31:0]
```

There are no AXI or AHB ports on `soc_top` or `fpga_top`. The inherited EH1 internal wrappers still retain conditionally compiled compatibility declarations and legacy signal names. The corresponding bus macros are disabled and these declarations do not form a functional external-memory path.

## Memory integration

The top propagates twelve independent synthesis initialization parameters through `veer_wrapper` into `mem`:

- `ICCM_LANE0_INIT_FILE` through `ICCM_LANE3_INIT_FILE`;
- `DCCM_BANK0_INIT_FILE` through `DCCM_BANK7_INIT_FILE`.

ICCM is implemented as four 8,192 x 32-bit synchronous RAM lanes. A 128-bit fetch block is returned one clock after the registered read request. Total capacity is 4 x 8,192 x 32 bits = 128 KiB.

DCCM is implemented as eight 2,048 x 32-bit synchronous RAM banks. Read address and bank selection are registered; data is returned one clock later. Total capacity is 8 x 2,048 x 32 bits = 64 KiB. Byte and halfword stores are merged in the LSU/store-buffer datapath before the physical 32-bit bank write, so the RAM backend does not require byte-write enable ports.

For simulation, the same RAM modules accept `+iccm_lane0=...` through `+iccm_lane3=...` and `+dccm_bank0=...` through `+dccm_bank7=...`. `run_verilator.py` now requires and supplies these twelve files for every image. The runtime path is excluded under `SYNTHESIS`; Vivado continues to use the fixed string parameters, preserving BRAM initialization and inference.

The address checker accepts only DCCM and the four local MMIO windows. Other data addresses produce a precise access fault; there is no external-memory escape route. Halfword/word accesses that violate natural alignment now trap consistently in both DCCM and MMIO, matching the frozen software contract and the selected RV32MI tests.

## CPU/FPU integration findings

- MISA reads `0x4000_1120`: RV32 with I, M and F set, C clear.
- IALIGN is 32 bits. Misaligned branch/JAL/JALR targets produce instruction-address-misaligned cause 0.
- RV32F uses 32 floating-point registers and FPnew single-precision execution. FP operations are serialized at the inherited EH1 control boundary to preserve precise retirement.
- `fflags`, `frm`, `fcsr`, `mstatus.FS` and FPU dirty-state propagation are present. FP instructions are illegal while FS is Off.
- This review fixed `mstatus.SD`: it is now set only when FS is Dirty (`11`), not for Initial or Clean.
- `FLW`/`FSW` use the regular LSU/DCCM path. External floating-point loads/stores are impossible because there is no external memory window.

## Local peripheral integration

The LSU local request path is single-outstanding. `local_peripheral_subsystem` decodes the four fixed windows and returns a response/error to the inherited LSU bus boundary. TIMER drives the machine timer interrupt. SYSCTRL software IRQ intentionally shares machine interrupt cause 7; the BSP distinguishes the pending source in software. UART IRQ is implemented at the peripheral boundary but not routed as a separate machine external interrupt in this minimal SoC.

The generated software headers and linker constants are current. SYSCTRL test status is `0x1000_3014`, and test code is `0x1000_3018`.

## Source-level checks run

The following checks passed:

- generated SoC contract freshness;
- JSON schema and checked-in data structure validation;
- memory map/software contract cross-check;
- RTL, Verilator and FPGA filelist path/duplication checks.

The image check intentionally failed at the first old image because its recorded memory-map hash is stale. This is useful evidence that the enhanced guard rejects obsolete images, not evidence of a current runnable firmware image.

## Blocking issues for Stage 3/4

### P0: stale simulation top

`tb/soc/soc_sim_top.sv` still imports the removed `soc_config_pkg` and `cpu_types_pkg`, instantiates the removed `soc_top_generic`, and expects an obsolete commit-trace interface. The C++ adapter expects the same old commit outputs. Therefore the 68-path Verilator filelist is structurally complete but cannot represent the current DUT contract.

Required Stage 3 action: create a current testbench wrapper around `soc_top`, derive done/pass/code from SYSCTRL outputs, and decide whether to (a) expose a new EH1 retirement/CSR trace for difftest or (b) temporarily disable difftest while preserving functional UART/status testing. Memory loading is already decoupled from model compilation through the twelve runtime plusargs. This is testbench work and is intentionally not performed by the RTL-development stage.

### P0: stale generated images

Existing `data/isa/` and `build/images/` artifacts were produced for an earlier memory map. They must be regenerated after the simulation wrapper is current. No `.mem` file from those stale manifests should be supplied to Verilator or Vivado.

### P1: dynamic proof absent

No compile/elaboration result currently proves that all inherited conditional compatibility ports close cleanly. No RV32UI/MI/UM/UF result proves architectural correctness, and no RT-Thread/CoreMark result proves software integration.

### P1: performance and FPGA closure absent

The design intent is 250 MHz and the software reports CoreMark/MHz from cycle ticks, but there is no post-route WNS/TNS, utilization, BRAM inference, UART transcript, 10,000-iteration runtime, or CoreMark/MHz measurement yet.

## Exit criteria for subsequent stages

Stage 3 is complete only when a current SoC testbench and adapter elaborate against `soc_top`, initialize all ICCM/DCCM memories, drive reset/UART, and terminate on SYSCTRL PASS/FAIL.

Stage 4 is complete only after rebuilding all images and obtaining passing focused smoke/trap tests, mandatory RV32UI/RV32MI/RV32UM/RV32UF gates, RT-Thread boot/FinSH, and CoreMark result validation. FPGA acceptance additionally requires positive post-route timing at 250 MHz, expected BRAM inference, a valid bitstream and a board UART transcript for `coremark 10000`.
