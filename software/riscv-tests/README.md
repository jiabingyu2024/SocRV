# riscv-tests integration

`upstream/` is a reproducibly fetched checkout of the official
`riscv-software-src/riscv-tests` repository.  It is immutable project input:
SocRV-specific linker, pass/fail protocol and image generation files live next
to it under `env/socrv/`.

Run `make deps` to fetch the locked commit and its locked `riscv-test-env`
submodule; `make deps-check` verifies both revisions. `make isa-data` compiles
the selected tests against the current SocRV Memory Map and regenerates
`data/isa/`.

The generated dataset contains RV32UI, RV32MI, RV32UM, RV32UF and RV32UD.
`make isa-gates` lists the available acceptance gates. The `current` gate is
the RV32I demo-core subset. The mandatory final integer gate is
RV32UI + RV32MI + RV32UM. RV32UF and RV32UD are generated as separate
single- and double-precision candidates until the CPU contract selects F or
FD.

RV32MI is the machine-mode test suite, not an ISA extension named MI. The
selection file also records exclusions: misaligned `ma_data` follows the
target trap policy, and the pinned upstream RV32UD Makefrag excludes `move`
because its RV32 implementation is unavailable.
