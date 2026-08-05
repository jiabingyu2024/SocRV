PYTHON ?= python
JOBS ?= 4
PROFILE ?= rtthread-coremark
SUITE ?= smoke
TRACE ?= 0
ISA_GATE ?= current
COREMARK_ITERATIONS ?= 3

.DEFAULT_GOAL := help

.PHONY: help env-check doctor deps deps-check soc-contract \
	soc-contract-check isa-data isa-data-check isa-gates validate-schemas \
	test-scripts check-generated-tree check-filelists check-memory-map \
	rtl-lint check software software-smoke software-trap-timer \
	software-rtthread software-fpga sim sim-smoke sim-trap-timer \
	sim-rtthread sim-coremark sim-isa sim-quick sim-full regression \
	fpga-build fpga-bitstream fpga-check fpga-program check-images \
	release release-check clean-software clean-images clean-sim \
	clean-regression clean-fpga clean

help:
	@$(PYTHON) scripts/project_cli.py help

env-check:
	@$(PYTHON) scripts/check_environment.py

doctor:
	@$(PYTHON) scripts/check_environment.py --verbose

deps:
	@$(PYTHON) scripts/fetch_dependencies.py

deps-check:
	@$(PYTHON) scripts/fetch_dependencies.py --verify

soc-contract:
	@$(PYTHON) scripts/generate_soc_contract.py

soc-contract-check:
	@$(PYTHON) scripts/generate_soc_contract.py --check

isa-data: deps-check
	@$(PYTHON) scripts/generate_isa_data.py

isa-data-check:
	@$(PYTHON) scripts/generate_isa_data.py --verify

isa-gates: isa-data-check
	@$(PYTHON) scripts/run_isa_tests.py --list-gates

validate-schemas:
	@$(PYTHON) scripts/validate_schemas.py

test-scripts:
	@$(PYTHON) -m unittest discover -s scripts/tests -v

check-generated-tree:
	@$(PYTHON) scripts/check_generated_tree.py

check-filelists:
	@$(PYTHON) scripts/check_filelists.py

check-memory-map:
	@$(PYTHON) scripts/check_memory_map.py

rtl-lint:
	@$(PYTHON) scripts/lint_rtl.py

check: env-check deps-check soc-contract-check isa-data-check \
	validate-schemas test-scripts check-generated-tree check-filelists \
	check-memory-map rtl-lint
	@$(PYTHON) scripts/project_cli.py message "static and foundational checks passed"

# Software images. software-fpga is the board image that waits for FinSH input.
software: deps-check
	@$(PYTHON) scripts/build_software.py --profile $(PROFILE)

software-smoke:
	@$(PYTHON) scripts/build_software.py --profile smoke

software-trap-timer:
	@$(PYTHON) scripts/build_software.py --profile trap-timer

software-rtthread: deps-check
	@$(PYTHON) scripts/build_software.py --profile rtthread

software-fpga: deps-check
	@$(PYTHON) scripts/build_software.py --profile rtthread-coremark

# Focused simulations. TRACE=1 is intended for a failing focused test.
sim: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile $(PROFILE) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-smoke:
	@$(PYTHON) scripts/run_verilator.py --profile smoke \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-trap-timer:
	@$(PYTHON) scripts/run_verilator.py --profile trap-timer \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-rtthread: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile rtthread \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-coremark: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile rtthread-coremark \
		--test rtthread-coremark-command-$(COREMARK_ITERATIONS) \
		--benchmark-iterations $(COREMARK_ITERATIONS) \
		--uart-command "coremark $(COREMARK_ITERATIONS)" \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-isa: isa-data-check
	@$(PYTHON) scripts/run_isa_tests.py --gate $(ISA_GATE)

# Daily CPU edit loop: current ISA gate, bare-metal, RT-Thread, CoreMark 3.
sim-quick:
	@$(MAKE) sim-smoke
	@$(MAKE) sim-isa ISA_GATE=current
	@$(MAKE) sim-rtthread
	@$(MAKE) sim-coremark COREMARK_ITERATIONS=3

# Milestone gate: full RV32UI/RV32MI/RV32UM target and a longer trend run.
sim-full:
	@$(MAKE) sim-isa ISA_GATE=final-base
	@$(MAKE) sim-rtthread
	@$(MAKE) sim-coremark COREMARK_ITERATIONS=10

regression: deps-check
	@$(PYTHON) scripts/run_regression.py --suite $(SUITE)

# Vivado is only invoked when the user explicitly runs fpga-build/program.
fpga-build: deps-check
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --jobs $(JOBS)

fpga-bitstream: fpga-build

fpga-check:
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --check-only

fpga-program:
	@$(PYTHON) scripts/program_board.py --profile $(PROFILE)

check-images:
	@$(PYTHON) scripts/check_images.py

release: fpga-check check-images
	@$(PYTHON) scripts/package_release.py --profile $(PROFILE)
	@$(PYTHON) scripts/verify_release.py --profile $(PROFILE)

release-check:
	@$(PYTHON) scripts/verify_release.py --profile $(PROFILE)

clean-software:
	@$(PYTHON) scripts/clean.py software

clean-images:
	@$(PYTHON) scripts/clean.py images

clean-sim:
	@$(PYTHON) scripts/clean.py sim

clean-regression:
	@$(PYTHON) scripts/clean.py regression

clean-fpga:
	@$(PYTHON) scripts/clean.py fpga

clean:
	@$(PYTHON) scripts/clean.py all
