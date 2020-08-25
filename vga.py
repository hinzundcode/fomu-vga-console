#!/usr/bin/env python3
# This variable defines all the external programs that this module
# relies on.  lxbuildenv reads this variable in order to ensure
# the build will finish without exiting due to missing third-party
# programs.
LX_DEPENDENCIES = ["icestorm", "yosys", "nextpnr-ice40"]
#LX_CONFIG = "skip-git" # This can be useful for workshops

# Import lxbuildenv to integrate the deps/ directory
import os,os.path,shutil,sys,subprocess
sys.path.insert(0, os.path.dirname(__file__))
import lxbuildenv

# Disable pylint's E1101, which breaks completely on migen
#pylint:disable=E1101

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.builder import Builder
from litex.soc.interconnect.csr import AutoCSR, CSRStatus, CSRStorage

#from litex_boards.partner.targets.fomu import BaseSoC, add_dfu_suffix
from litex_boards.targets.fomu import BaseSoC, add_dfu_suffix

from valentyusb.usbcore import io as usbio
from valentyusb.usbcore.cpu import dummyusb

from litex.soc.integration.soc_core import SoCCore

import argparse

class VGA(Module, AutoCSR):
    def __init__(self, pins, clk):
        self.glyph = CSRStorage(8)
        
        self.specials.fb = Memory(8, 80*30)
        self.specials.fb_read = self.fb.get_port(mode=READ_FIRST, clock_domain="vga")
        
        self.comb += [
            pins[1].eq(0),
        ]
        self.specials += Instance(
            'vga',
            i_clk=clk,
            o_hsync=pins[2],
            o_vsync=pins[3],
            o_color=pins[0],
            o_framebuffer_addr=self.fb_read.adr,
            i_framebuffer_data=self.fb_read.dat_r
        )

class CRG(Module):
    def __init__(self, platform):
        clk48_raw = platform.request("clk48")
        clk12 = Signal()
        clk25 = Signal()

        reset_delay = Signal(12, reset=4095)
        self.clock_domains.cd_por = ClockDomain()
        self.reset = Signal()

        self.clock_domains.cd_sys = ClockDomain()
        self.clock_domains.cd_vga = ClockDomain()
        self.clock_domains.cd_usb_12 = ClockDomain()
        self.clock_domains.cd_usb_48 = ClockDomain()

        platform.add_period_constraint(self.cd_usb_48.clk, 1e9/48e6)
        platform.add_period_constraint(self.cd_sys.clk, 1e9/12e6)
        platform.add_period_constraint(self.cd_vga.clk, 1e9/25125000)
        platform.add_period_constraint(self.cd_usb_12.clk, 1e9/12e6)
        platform.add_period_constraint(clk48_raw, 1e9/48e6)

        # POR reset logic- POR generated from sys clk, POR logic feeds sys clk
        # reset.
        self.comb += [
            self.cd_por.clk.eq(self.cd_sys.clk),
            self.cd_sys.rst.eq(reset_delay != 0),
            self.cd_vga.rst.eq(reset_delay != 0),
            self.cd_usb_12.rst.eq(reset_delay != 0),
            self.cd_usb_48.rst.eq(reset_delay != 0),
        ]

        self.specials += Instance("clock12",
            i_clk48=clk48_raw,
            o_clk12=clk12)
        
        self.specials += Instance(
            "SB_PLL40_CORE",
            p_DIVR = 3,
            p_DIVF = 66,
            p_DIVQ = 5,
            p_FILTER_RANGE = 1,
            p_FEEDBACK_PATH = "SIMPLE",
            p_PLLOUT_SELECT = "GENCLK",
            i_REFERENCECLK = clk48_raw,
            o_PLLOUTCORE = clk25,
            i_RESETB = 1,
            i_BYPASS = 0,
        )

        self.comb += self.cd_usb_48.clk.eq(clk48_raw)
        self.comb += self.cd_sys.clk.eq(clk12)
        self.comb += self.cd_usb_12.clk.eq(clk12)
        self.comb += self.cd_vga.clk.eq(clk25)

        self.sync.por += \
            If(reset_delay != 0,
                reset_delay.eq(reset_delay - 1)
            )
        self.specials += AsyncResetSynchronizer(self.cd_por, self.reset)


class SimpleSoC(SoCCore):
    def __init__(self, board, **kwargs):
        if board == "pvt":
            from litex_boards.platforms.fomu_pvt import Platform
        elif board == "hacker":
            from litex_boards.platforms.fomu_hacker import Platform
        elif board == "evt":
            from litex_boards.platforms.fomu_evt import Platform
        else:
            raise ValueError("unrecognized fomu board: {}".format(board))
        platform = Platform()
        clk_freq = int(12e6)
        SoCCore.__init__(self,
            platform,
            clk_freq,
            integrated_sram_size=0,
            with_uart=False,
            with_timer=False,
            cpu_type=None,
            **kwargs)

        self.submodules.crg = CRG(platform)

        from valentyusb.usbcore.cpu import epfifo, dummyusb
        usb_pads = platform.request("usb")
        usb_iobuf = usbio.IoBuf(usb_pads.d_p, usb_pads.d_n, usb_pads.pullup)
        
        self.submodules.usb = dummyusb.DummyUsb(usb_iobuf, debug=True)
        self.add_wb_master(self.usb.debug_bridge.wishbone)

def main():
    parser = argparse.ArgumentParser(
        description="Build Fomu Main Gateware")
    parser.add_argument(
        "--seed", default=0, help="seed to use in nextpnr"
    )
    parser.add_argument(
        "--placer", default="heap", choices=["sa", "heap"], help="which placer to use in nextpnr"
    )
    parser.add_argument(
        "--board", choices=["evt", "pvt", "hacker"], required=True,
        help="build for a particular hardware board"
    )
    args = parser.parse_args()

    #soc = BaseSoC(args.board, pnr_seed=args.seed, pnr_placer=args.placer, usb_bridge=True)
    soc = SimpleSoC(args.board,
        pnr_seed=args.seed,
        pnr_placer=args.placer,
        usb_bridge=True)
    
    clk = soc.crg.cd_vga.clk
    pins = [soc.platform.request('user_touch_n', i) for i in range(0, 4)]
    soc.submodules.vga = VGA(pins, clk)
    soc.add_csr("vga")
    soc.add_csr("vga_fb")
    
    soc.platform.add_source("clock12.v")
    #soc.platform.add_source("font.v")
    #soc.platform.add_source("buffer.v")
    #soc.platform.add_source("hvsync_generator.v")
    soc.platform.add_source("vga.v")

    builder = Builder(soc,
                      output_dir="build", csr_csv="build/csr.csv",
                      compile_software=False)
    vns = builder.build()
    soc.do_exit(vns)
    add_dfu_suffix(os.path.join('build', 'gateware', 'fomu_pvt.bin'))


if __name__ == "__main__":
    main()
