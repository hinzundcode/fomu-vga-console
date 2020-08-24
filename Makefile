REQUIRED_TIMING_MHZ = 25.125

# Simple Fomu Makefile
# --------------------
# This Makefile shows the steps to generate a DFU loadable image onto
# Fomu hacker board.

# Different Fomu hardware revisions are wired differently and thus
# require different configurations for yosys and nextpnr.
# Configuration is performed by setting the environment variable FOMU_REV accordingly.
#ifeq ($(FOMU_REV),evt1)
#YOSYSFLAGS?= -D EVT=1
#PNRFLAGS  ?= --up5k --package sg48 --pcf ../pcf/fomu-evt2.pcf
#ICETIMEFLAGS ?= -d up5k -P sg48 -p ../pcf/fomu-evt2.pcf
#else ifeq ($(FOMU_REV),evt2)
#YOSYSFLAGS?= -D EVT=1
#PNRFLAGS  ?= --up5k --package sg48 --pcf ../pcf/fomu-evt2.pcf
#ICETIMEFLAGS ?= -d up5k -P sg48 -p ../pcf/fomu-evt2.pcf
#else ifeq ($(FOMU_REV),evt3)
#YOSYSFLAGS?= -D EVT=1
#PNRFLAGS  ?= --up5k --package sg48 --pcf ../pcf/fomu-evt3.pcf
#ICETIMEFLAGS ?= -d up5k -P sg48 -p ../pcf/fomu-evt3.pcf
#else ifeq ($(FOMU_REV),hacker)
#YOSYSFLAGS?= -D HACKER=1
#PNRFLAGS  ?= --up5k --package uwg30 --pcf ../pcf/fomu-hacker.pcf
#ICETIMEFLAGS ?= -d up5k -P uwg30 -p ../pcf/fomu-hacker.pcf
#else ifeq ($(FOMU_REV),pvt)
#YOSYSFLAGS?= -D PVT=1
#PNRFLAGS  ?= --up5k --package uwg30 --pcf ../pcf/fomu-pvt.pcf
#ICETIMEFLAGS ?= -d up5k -P uwg30 -p ../pcf/fomu-pvt.pcf
#else
#$(error Unrecognized FOMU_REV value. must be "evt1", "evt2", "evt3", "pvt", or "hacker")
#endif
YOSYSFLAGS?= -D PVT=1
PNRFLAGS  ?= --up5k --package uwg30 --pcf ./fomu-pvt.pcf
ICETIMEFLAGS ?= -d up5k -P uwg30 -p ./fomu-pvt.pcf

# Default target: run all required targets to build the DFU image.
all: vga_console.dfu
	@true

.DEFAULT: all

# Use *Yosys* to generate the synthesized netlist.
# This is called the **synthesis** and **tech mapping** step.
vga_console.json: vga_console.v hvsync_generator.v buffer.v font.v
	yosys \
		$(YOSYSFLAGS) \
		-p 'synth_ice40 -top top -json vga_console.json' vga_console.v

# Use **nextpnr** to generate the FPGA configuration.
# This is called the **place** and **route** step.
vga_console.asc: vga_console.json
	nextpnr-ice40 \
		$(PNRFLAGS) \
		--json vga_console.json \
		--asc vga_console.asc
	set -o pipefail; icetime $(ICETIMEFLAGS) -c $(REQUIRED_TIMING_MHZ) -t vga_console.asc | tee vga_console.timing.txt

# Use icepack to convert the FPGA configuration into a "bitstream" loadable onto the FPGA.
# This is called the bitstream generation step.
vga_console.bit: vga_console.asc
	icepack vga_console.asc vga_console.bit

# Use dfu-suffix to generate the DFU image from the FPGA bitstream.
vga_console.dfu: vga_console.bit
	cp vga_console.bit vga_console.dfu
	dfu-suffix -v 1209 -p 70b1 -a vga_console.dfu

# Use df-util to load the DFU image onto the Fomu.
load: vga_console.dfu
	dfu-util -D vga_console.dfu

.PHONY: load

# Cleanup the generated files.
clean:
	-rm -f vga_console.json 	# Generate netlist
	-rm -f vga_console.asc 	# FPGA configuration
	-rm -f vga_console.bit 	# FPGA bitstream
	-rm -f vga_console.dfu 	# DFU image loadable onto the Fomu
	-rm -f vga_console.timing.txt

.PHONY: clean
