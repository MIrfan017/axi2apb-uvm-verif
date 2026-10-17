# ============================================================================
# Makefile  -  AXI -> APB bridge UVM testbench (Synopsys VCS)
#
#   make compile TEST=<test_name>       -> compile only
#   make sim     TEST=<test_name>       -> simulate only (uses existing simv)
#   make run     TEST=<test_name>       -> compile + simulate
#   make directed                       -> run directed test
#   make random TEST=<rand_test>        -> run specific random test
#   make regress                        -> run full regression (directed + all random)
#   make cov_merge                      -> merge coverage from all builds
#   make gui     TEST=<test_name>       -> open waveform
#   make clean | allclean | clean_logs
# ============================================================================

# ---------------------------------------------------------------------------
# Default knobs (override on command line, e.g. `make run TEST=foo SEED=42`)
# ---------------------------------------------------------------------------
TEST      ?= axi_apb_directed_test
SEED      ?= 1
VERBOSITY ?= UVM_MEDIUM
WAVE      ?= 1
TIME_OUT  ?= 100000000

# ---------------------------------------------------------------------------
# Test lists (used by `regress`)
# ---------------------------------------------------------------------------
DIRECTED_TESTS = axi_apb_directed_test

RANDOM_TESTS   = axi_apb_rand_mixed_test \
                 axi_apb_rand_write_heavy_test \
                 axi_apb_rand_read_heavy_test \
                 axi_apb_rand_backpressure_test \
                 axi_apb_rand_edge_test

REGRESS_SEEDS  = 1 2 3

# ---------------------------------------------------------------------------
# UVM simulate args
# ---------------------------------------------------------------------------
SIM_ARGS  = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY) \
            +UVM_TIMEOUT=$(TIME_OUT) +ntb_random_seed=$(SEED)

ifeq ($(WAVE),1)
SIM_ARGS += +WAVE
endif

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------
compile:
	rm -f compile.log
	mkdir -p ./out
	vcs -full64 -sverilog -ntb_opts uvm-1.2 \
	    -timescale=1ns/1ps \
	    -lca \
	    -debug_access+all -kdb \
	    -cm line+cond+tgl+assert+branch \
	    -f build.flist \
	    -l compile.log || (echo "VCS COMPILE FAILED - see compile.log"; exit 1)
	rm -rf ./out/build_$(TEST)
	mkdir  ./out/build_$(TEST)
	mv csrc simv.daidir simv.vdb simv vc_hdrs.h compile.log ./out/build_$(TEST)
	@if [ -f compile_full.log ];  then mv compile_full.log  ./out/; fi
	@if [ -f compile_stdout.txt ]; then mv compile_stdout.txt ./out/; fi

# ---------------------------------------------------------------------------
# Simulate
# ---------------------------------------------------------------------------
sim:
	cd ./out/build_$(TEST) && ./simv \
	    -cm line+cond+tgl+assert+branch \
	    -cm_name $(TEST) \
	    $(SIM_ARGS) > log_build_$(TEST).log
	@echo "---------------- result ($(TEST)) ----------------"
	@grep -E "TEST PASSED|TEST FAILED|UVM_ERROR :|UVM_FATAL :" \
	    ./out/build_$(TEST)/log_build_$(TEST).log || true
	@echo "Log: ./out/build_$(TEST)/log_build_$(TEST).log"

run: compile sim

# ---------------------------------------------------------------------------
# Convenience single-test shortcuts
# ---------------------------------------------------------------------------
directed:
	$(MAKE) run TEST=axi_apb_directed_test WAVE=0

# make random TEST=axi_apb_rand_mixed_test SEED=3
random:
	$(MAKE) run TEST=$(TEST) SEED=$(SEED) WAVE=0

# ---------------------------------------------------------------------------
# Regression (Directed + All Random tests x SEEDS)
# ---------------------------------------------------------------------------
regress:
	@echo "=========================================================="
	@echo " Starting Regression"
	@echo "   Directed : $(DIRECTED_TESTS)"
	@echo "   Random   : $(RANDOM_TESTS)"
	@echo "   Seeds    : $(REGRESS_SEEDS)"
	@echo "=========================================================="
	@for t in $(DIRECTED_TESTS); do \
	    echo "--> Running $$t ..."; \
	    $(MAKE) run TEST=$$t SEED=1 WAVE=0 > /dev/null 2>&1; \
	    grep -q "TEST PASSED" out/build_$$t/log_build_$$t.log \
	        && echo "    [PASS] $$t (seed 1)" \
	        || (echo "    [FAIL] $$t (seed 1) -- see out/build_$$t/log_build_$$t.log" && exit 1); \
	done
	@for t in $(RANDOM_TESTS); do \
	    for s in $(REGRESS_SEEDS); do \
	        echo "--> Running $$t (SEED=$$s) ..."; \
	        $(MAKE) run TEST=$$t SEED=$$s WAVE=0 > /dev/null 2>&1; \
	        grep -q "TEST PASSED" out/build_$$t/log_build_$$t.log \
	            && echo "    [PASS] $$t (seed $$s)" \
	            || (echo "    [FAIL] $$t (seed $$s) -- see out/build_$$t/log_build_$$t.log" && exit 1); \
	    done \
	done
	@echo "=========================================================="
	@echo " Regression Complete: ALL TESTS PASSED"
	@echo "=========================================================="

# ---------------------------------------------------------------------------
# Coverage
# ---------------------------------------------------------------------------
cov:
	urg -full64 -lca -report ./out/coverage_report -dir ./out/build_*/*.vdb

cov_merge:
	@echo "Merging coverage for all builds..."
	urg -full64 -lca \
	    -dir ./out/build_axi_apb_*/simv.vdb \
	    -report ./out/cov_final_excluded \
	    -format text
	@echo "=========================================================="
	@echo " FINAL DUT COVERAGE (axi2apb_i & tb_top)"
	@echo "=========================================================="
	@grep -A 4 "axi2apb_i" ./out/cov_final_excluded/hierarchy.txt | head -10
	@echo "--------------------------------------------------------"
	@echo " FUNCTIONAL COVERAGE (Groups)"
	@echo "--------------------------------------------------------"
	@grep -A 4 "Total Groups Coverage Summary" ./out/cov_final_excluded/dashboard.txt
	@echo "=========================================================="
	@echo "HTML Report: ./out/cov_final_excluded/dashboard.html"

dve_cov:
	dve -full64 -covdir ./out/build_$(TEST)/simv.vdb

# ---------------------------------------------------------------------------
# Waveform
# ---------------------------------------------------------------------------
gui:
	cd ./out/build_$(TEST) && dve -full64 -vpd waveform.vpd

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
clean:
	rm -rf ./out/build_$(TEST)

allclean:
	rm -rf ./out/*

clean_logs:
	rm -f compile_full.log compile_stdout.txt sim_stdout.txt urg_err.txt

.PHONY: compile sim run directed random regress cov cov_merge dve_cov gui clean allclean clean_logs