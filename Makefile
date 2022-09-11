WORKDIR  = work
WAVESDIR = waves

CPU_RTL  = $(wildcard ./cpu/rtl/*.vhdl)
CPU_TBS  = $(wildcard ./cpu/tbs/*.vhdl)
SIM_RTL  = $(wildcard ./sim/rtl/*.vhdl)
SOC_RTL  = $(wildcard ./soc/rtl/*.vhdl)
SOC_TBS  = $(wildcard ./soc/tbs/*.vhdl)
UART_RTL = $(wildcard ./uart/rtl/*.vhdl)
UART_TBS = $(wildcard ./uart/rtl/*.vhdl)

GHDL = ghdl
GHDLFLAGS = --workdir=$(WORKDIR) --ieee=synopsys

$(WORKDIR):
	mkdir $@

$(WAVESDIR):
	mkdir $@

$(WORKDIR)/work-obj93.cf: $(CPU_RTL) $(CPU_TBS) $(SIM_RTL) $(SOC_RTL) $(SOC_TBS) $(UART_RTL) $(UART_TBS) $(WORKDIR)
	$(GHDL) -i $(GHDLFLAGS) $(CPU_RTL) $(CPU_TBS) $(SIM_RTL) $(SOC_RTL) $(SOC_TBS) $(UART_RTL) $(UART_TBS)

$(WAVESDIR)/%.ghw: ./tbs/%.vhdl $(WORKDIR)/work-obj93.cf $(WAVESDIR)
	$(GHDL) -m $(GHDLFLAGS) $*
	$(GHDL) -r $(GHDLFLAGS) $* --stop-time=50us --ieee-asserts=disable --wave=$@

$(WAVESDIR)/soc_tb.ghw: ./tbs/soc_tb.vhdl $(WORKDIR)/work-obj93.cf $(WAVESDIR)
	$(GHDL) -m $(GHDLFLAGS) soc_tb
	$(GHDL) -r $(GHDLFLAGS) soc_tb --stop-time=1500ms --ieee-asserts=disable -gPROGRAM=sw/build/hello_world.bin --wave=$@

.PHONY: soc_tb
soc_tb: ./soc/tbs/soc_tb.vhdl $(WORKDIR)/work-obj93.cf
	$(GHDL) -m $(GHDLFLAGS) soc_tb
	$(GHDL) -r $(GHDLFLAGS) soc_tb --max-stack-alloc=0 --ieee-asserts=disable -gPROGRAM=$(BIN_FILE)

$(WAVESDIR)/sim.ghw: $(WORKDIR)/work-obj93.cf $(WAVESDIR)
	$(GHDL) -m $(GHDLFLAGS) sim;
	$(GHDL) -r $(GHDLFLAGS) sim --stop-time=200us --max-stack-alloc=0 --ieee-asserts=disable -gBIN_FILE=$(BIN_FILE) --wave=$@;

.PHONY: sim
sim: $(WORKDIR)/work-obj93.cf
	$(GHDL) -m $(GHDLFLAGS) sim;
	$(GHDL) -r $(GHDLFLAGS) sim --max-stack-alloc=0 --ieee-asserts=disable -gBIN_FILE=$(BIN_FILE);

RV_ARCH_TEST_DIR=../riscv-arch-test/
export TARGETDIR ?= $(shell pwd)/compliance/
export XLEN=32
export RISCV_TARGET=leaf

.PHONY: compliance-test
compliance-test: $(WORKDIR)/work-obj93.cf
	$(MAKE) -C $(RV_ARCH_TEST_DIR) build;
	$(GHDL) -m $(GHDLFLAGS) sim;
	bins=$$(find $(RV_ARCH_TEST_DIR)/work/rv32i_m/I/ -name "*.bin"); \
	for bin in $$bins; do \
        test=$$(basename -s .elf.bin $$bin); \
        echo "running test: $$test"; \
        $(GHDL) -r $(GHDLFLAGS) sim --max-stack-alloc=0 --ieee-asserts=disable -gBIN_FILE=$$bin | xxd -c 4 -p > $(RV_ARCH_TEST_DIR)/work/rv32i_m/I/$$test.signature.output; \
    done
	$(MAKE) -C $(RV_ARCH_TEST_DIR) verify

.PHONY: clean
clean:
	rm -rf $(WORKDIR) $(WAVESDIR)
	$(MAKE) -C $(RV_ARCH_TEST_DIR) clean;