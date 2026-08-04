PYTHON ?= python
JOBS ?= 4
PROFILE ?= smoke
SUITE ?= smoke
TRACE ?= 0

.DEFAULT_GOAL := help

.PHONY: help env-check doctor deps deps-check soc-contract soc-contract-check \
	isa-data isa-data-check isa-regression data-isa-import data-isa-check \
	data-isa-legacy-import data-isa-legacy-check validate-schemas test-scripts \
	check-generated-tree check-filelists check-memory-map rtl-lint check \
	software software-smoke software-trap-timer software-rtthread \
	software-coremark coremark-smoke coremark-rtthread \
	sim sim-smoke sim-trap-timer sim-rtthread sim-coremark-smoke \
	sim-coremark-rtthread regression fpga-bitstream fpga-check fpga-program \
	check-images release release-check clean-software clean-images clean-sim \
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

isa-regression: isa-data-check
	@$(PYTHON) scripts/run_isa_tests.py

# Compatibility aliases. The authoritative dataset is generated from the
# locked official riscv-tests checkout, not copied from the previous project.
data-isa-import: isa-data

data-isa-check: isa-data-check

data-isa-legacy-import:
	@$(PYTHON) scripts/import_legacy_isa.py

data-isa-legacy-check:
	@$(PYTHON) scripts/import_legacy_isa.py --verify

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

check: env-check deps-check soc-contract-check isa-data-check validate-schemas test-scripts check-generated-tree check-filelists check-memory-map rtl-lint
	@$(PYTHON) scripts/project_cli.py message "static and foundational checks passed"

software: deps-check
	@$(PYTHON) scripts/build_software.py --profile $(PROFILE)

software-smoke:
	@$(PYTHON) scripts/build_software.py --profile smoke

software-trap-timer:
	@$(PYTHON) scripts/build_software.py --profile trap-timer

software-rtthread: deps-check
	@$(PYTHON) scripts/build_software.py --profile rtthread

software-coremark: deps-check
	@$(PYTHON) scripts/build_software.py --profile coremark-baremetal

coremark-smoke: deps-check
	@$(PYTHON) scripts/build_software.py --profile coremark-smoke

coremark-rtthread: deps-check
	@$(PYTHON) scripts/build_software.py --profile coremark-rtthread

sim: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile $(PROFILE) $(if $(filter 1,$(TRACE)),--trace,)

sim-smoke:
	@$(PYTHON) scripts/run_verilator.py --profile smoke $(if $(filter 1,$(TRACE)),--trace,)

sim-trap-timer:
	@$(PYTHON) scripts/run_verilator.py --profile trap-timer $(if $(filter 1,$(TRACE)),--trace,)

sim-rtthread: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile rtthread $(if $(filter 1,$(TRACE)),--trace,)

sim-coremark-smoke: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile coremark-smoke $(if $(filter 1,$(TRACE)),--trace,)

sim-coremark-rtthread: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile coremark-rtthread $(if $(filter 1,$(TRACE)),--trace,)

regression: deps-check
	@$(PYTHON) scripts/run_regression.py --suite $(SUITE)

check-images:
	@$(PYTHON) scripts/check_images.py

fpga-bitstream: deps-check
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --jobs $(JOBS)

fpga-check:
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --check-only

fpga-program:
	@$(PYTHON) scripts/program_board.py --profile $(PROFILE)

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
