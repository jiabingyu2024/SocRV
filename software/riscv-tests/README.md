# riscv-tests integration

`upstream/` is a reproducibly fetched checkout of the official
`riscv-software-src/riscv-tests` repository.  It is immutable project input:
SocRV-specific linker, pass/fail protocol and image generation files live next
to it under `env/socrv/`.

Run `make deps` to fetch the locked commit and `make deps-check` to verify it.
`make isa-data` compiles the selected RV32I architectural tests against the
current SocRV Memory Map and regenerates `data/isa/`.
