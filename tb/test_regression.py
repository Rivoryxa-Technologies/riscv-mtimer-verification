"""The regression as it existed before the bug report.

It checks counting, the prescaler, and that MTIP rises when mtime reaches
mtimecmp. It passes on the seeded bug, which is how the bug escaped.
"""
import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
from mtimer_env import start, write, read, cycles, MTIME, MTIMECMP, DIV


@cocotb.test()
async def test_counts_every_cycle(dut):
    await start(dut)
    before = await read(dut, MTIME)
    await cycles(dut, 20)
    after = await read(dut, MTIME)
    assert after - before >= 20, f"mtime advanced {after - before}, expected at least 20"


@cocotb.test()
async def test_prescaler(dut):
    await start(dut)
    await write(dut, DIV, 4)
    await write(dut, MTIME, 0)
    await cycles(dut, 40)
    value = await read(dut, MTIME)
    assert 9 <= value <= 11, f"mtime {value} after 40 cycles with div 4, expected about 10"


@cocotb.test()
async def test_mtip_rises_at_compare(dut):
    await start(dut)
    await write(dut, MTIME, 0)
    await write(dut, MTIMECMP, 30)
    seen = False
    for _ in range(60):
        await ReadOnly()
        if int(dut.mtip.value) == 1:
            seen = True
            break
        await RisingEdge(dut.clk)
    assert seen, "MTIP never rose after mtime reached mtimecmp"
