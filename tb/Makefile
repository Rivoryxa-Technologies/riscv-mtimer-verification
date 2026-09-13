# cocotb with Verilator. Line coverage is written to coverage.dat.
SIM ?= verilator
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(abspath ../rtl/mtimer.sv)
COCOTB_TOPLEVEL = mtimer
EXTRA_ARGS += --coverage-line -Wno-fatal
ifeq ($(BUG),1)
  EXTRA_ARGS += +define+SEEDED_BUG
endif
COCOTB_TEST_MODULES ?= test_regression

include $(shell cocotb-config --makefiles)/Makefile.sim
