PYTHON ?= python
JOBS ?= 4
PROFILE ?= rtthread-coremark
SUITE ?= smoke
TRACE ?= 0
ISA_GATE ?= current
COREMARK_ITERATIONS ?= 3
CORE_MHZ ?= 125
ITER_TAG ?= manual
VIVADO_STAGE ?= synth
VIVADO_BUILD ?= build/vivado/kintex7-$(PROFILE)-$(CORE_MHZ)mhz
ANALYZE_ALL ?= 0
PATH_GROUP ?= category
PATH_LIMIT ?= 15
PATH_INDEX ?= 1
PATH_MODE ?= chain
UTIL_STAGE ?= auto
UTIL_DEPTH ?= 4
UTIL_METRIC ?= luts
UTIL_LIMIT ?= 30
UTIL_FILTER ?=
UTIL_DIFF ?=
COREMARK_TARGET_ITERATIONS ?= 2000
DIFFTEST ?= 0
DIFFTEST_MODE ?= ram-strict
DIFFTEST_ISA ?= rv32imf_zicsr

.DEFAULT_GOAL := help

.PHONY: help env-check doctor deps deps-check soc-contract \
	soc-contract-check isa-data isa-data-check isa-gates validate-schemas \
	test-scripts check-generated-tree check-filelists check-memory-map \
	rtl-lint check software software-smoke software-trap-timer \
	software-rtthread software-fpga sim sim-smoke sim-trap-timer \
	sim-rtthread sim-msh sim-coremark sim-isa sim-quick sim-full regression \
	difftest-build difftest-selftest diff-isa diff-smoke diff-rtthread diff-replay \
	fpga-build fpga-synth fpga-impl fpga-bitstream fpga-check fpga-analyze fpga-program check-images \
	fpga-paths fpga-path fpga-util \
	iter-status iter-trend \
	rtl-iteration \
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
		$(if $(filter 1,$(DIFFTEST)),--difftest --difftest-mode $(DIFFTEST_MODE) --difftest-isa $(DIFFTEST_ISA),) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-smoke:
	@$(PYTHON) scripts/run_verilator.py --profile smoke \
		$(if $(filter 1,$(DIFFTEST)),--difftest --difftest-mode soc-mmio --difftest-isa $(DIFFTEST_ISA),) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-trap-timer:
	@$(PYTHON) scripts/run_verilator.py --profile trap-timer \
		$(if $(filter 1,$(DIFFTEST)),--difftest --difftest-mode soc-mmio --difftest-isa $(DIFFTEST_ISA),) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-rtthread: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile rtthread \
		$(if $(filter 1,$(DIFFTEST)),--difftest --difftest-mode soc-mmio --difftest-isa $(DIFFTEST_ISA),) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-msh: deps-check
	@$(PYTHON) scripts/run_regression.py --suite msh \
		$(if $(filter 1,$(DIFFTEST)),--difftest,) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-coremark: deps-check
	@$(PYTHON) scripts/run_verilator.py --profile rtthread-coremark \
		--test rtthread-coremark-command-$(COREMARK_ITERATIONS) \
		--benchmark-iterations $(COREMARK_ITERATIONS) \
		--uart-command "coremark $(COREMARK_ITERATIONS)" \
		--uart-followup-command "ps" \
		--uart-followup-command "help" \
		--uart-expect "List threads in the system" \
		--uart-expect "RT-Thread shell help" \
		$(if $(filter 1,$(DIFFTEST)),--difftest --difftest-mode soc-mmio --difftest-isa $(DIFFTEST_ISA),) \
		$(if $(filter 1,$(TRACE)),--trace,)

sim-isa: isa-data-check
	@$(PYTHON) scripts/run_isa_tests.py --gate $(ISA_GATE) \
		$(if $(filter 1,$(DIFFTEST)),--difftest --difftest-isa $(DIFFTEST_ISA),)

difftest-build: deps-check
	@$(PYTHON) scripts/build_spike.py --jobs $(JOBS)
	@$(PYTHON) scripts/run_verilator.py --profile smoke --build-only --difftest

difftest-selftest: difftest-build
	@$(PYTHON) scripts/difftest_selftest.py

diff-isa: difftest-build isa-data-check
	@$(PYTHON) scripts/run_isa_tests.py --gate $(ISA_GATE) \
		--difftest --difftest-isa $(DIFFTEST_ISA) --no-rtl-build

diff-smoke: difftest-build
	@$(PYTHON) scripts/run_verilator.py --profile smoke --difftest \
		--difftest-mode soc-mmio --difftest-isa $(DIFFTEST_ISA) \
		--no-rtl-build

diff-rtthread: difftest-build
	@$(PYTHON) scripts/run_verilator.py --profile rtthread --difftest \
		--difftest-mode soc-mmio --difftest-isa $(DIFFTEST_ISA) \
		--uart-command socrv_info \
		--uart-prompt "msh >" \
		--checker uart-command-test-status-and-uart \
		--uart-expect "SocRV march=rv32imf_zicsr" --no-rtl-build

diff-replay:
	@$(PYTHON) scripts/replay_difftest.py --result "$(RESULT)" \
		$(if $(filter 1,$(TRACE)),--trace,)

# Daily CPU edit loop: current ISA gate, bare-metal, RT-Thread, CoreMark 3.
sim-quick:
	@$(MAKE) sim-smoke
	@$(MAKE) sim-isa ISA_GATE=current
	@$(MAKE) sim-rtthread
	@$(MAKE) sim-coremark COREMARK_ITERATIONS=3

# Milestone gate: RV32UI/RV32MI/RV32UM/RV32UF and a longer trend run.
sim-full:
	@$(MAKE) sim-isa ISA_GATE=final-base
	@$(MAKE) sim-rtthread
	@$(MAKE) sim-msh
	@$(MAKE) sim-coremark COREMARK_ITERATIONS=10

regression: deps-check
	@$(PYTHON) scripts/run_regression.py --suite $(SUITE)

# Vivado is only invoked when the user explicitly runs fpga-build/program.
fpga-build: deps-check
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --jobs $(JOBS) --core-mhz $(CORE_MHZ)

fpga-synth: deps-check
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --jobs $(JOBS) --core-mhz $(CORE_MHZ) --stage synth --run-tag $(ITER_TAG) --all-violations --no-software-build

fpga-impl: deps-check
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --jobs $(JOBS) --core-mhz $(CORE_MHZ) --stage impl --run-tag $(ITER_TAG) --all-violations --no-software-build

fpga-bitstream: fpga-build

fpga-check:
	@$(PYTHON) scripts/run_vivado.py --profile $(PROFILE) --core-mhz $(CORE_MHZ) --check-only

fpga-analyze:
	@$(PYTHON) scripts/analyze_vivado_reports.py --build-root $(VIVADO_BUILD) --stage $(VIVADO_STAGE) $(if $(filter 1,$(ANALYZE_ALL)),--export-all,)

fpga-paths:
	@$(PYTHON) scripts/query_timing_paths.py --build-root $(VIVADO_BUILD) --group $(PATH_GROUP) --limit $(PATH_LIMIT)

fpga-path:
	@$(PYTHON) scripts/show_timing_path.py --build-root $(VIVADO_BUILD) --stage $(VIVADO_STAGE) --index $(PATH_INDEX) --mode $(PATH_MODE)

fpga-util:
	@$(PYTHON) scripts/summarize_utilization.py --build-root $(VIVADO_BUILD) --stage $(UTIL_STAGE) --depth $(UTIL_DEPTH) --metric $(UTIL_METRIC) --limit $(UTIL_LIMIT) $(if $(UTIL_FILTER),--filter $(UTIL_FILTER),) $(if $(UTIL_DIFF),--diff $(UTIL_DIFF),)

iter-status:
	@$(PYTHON) scripts/iteration_status.py $(if $(VIVADO_BUILD),--build-root $(VIVADO_BUILD),) --iterations $(COREMARK_TARGET_ITERATIONS)

iter-trend:
	@$(PYTHON) scripts/iteration_status.py --trend

rtl-iteration:
	@$(PYTHON) scripts/run_optimization_iteration.py --tag $(ITER_TAG) --core-mhz $(CORE_MHZ) --jobs $(JOBS) --vivado-stage $(VIVADO_STAGE)

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
