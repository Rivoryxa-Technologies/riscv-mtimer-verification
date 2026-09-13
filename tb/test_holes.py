"""Directed test written to close coverage hole A: release after a debug halt.

The original regression never raised halt, so the halted and resume branches
were never exercised.
"""
import cocotb
from mtimer_env import start, write, read, cycles, MTIME


@cocotb.test()
async def test_halt_stops_and_resumes_counting(dut):
    await start(dut)
    await write(dut, MTIME, 0)
    dut.halt.value = 1
    await cycles(dut, 3)
    held = await read(dut, MTIME)
    await cycles(dut, 20)
    still = await read(dut, MTIME)
    assert still == held, f"mtime moved from {held} to {still} while halted"
    dut.halt.value = 0
    await cycles(dut, 20)
    after = await read(dut, MTIME)
    assert after > still, "mtime did not resume counting after halt was released"


@cocotb.test()
async def test_read_unused_address(dut):
    """Directed test written to close coverage hole D: a read of the unused address 3."""
    await start(dut)
    await write(dut, MTIME, 0x1234)
    value = await read(dut, 3)
    assert value == 0, f"read of unused address 3 returned {value:#x}, expected 0"
