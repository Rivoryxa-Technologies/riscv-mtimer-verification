"""Reproduction of the bug report.

Report: "The timer interrupt is sometimes missed. If the core has interrupts
disabled when mtime reaches mtimecmp, the interrupt is gone by the time they
are enabled again."

The RISC-V privileged specification requires MTIP to stay pending while
mtime >= mtimecmp. These tests check exactly that.
"""
import cocotb
from mtimer_env import start, write, cycles, mtip, MTIME, MTIMECMP


@cocotb.test()
async def test_mtip_stays_pending_after_compare(dut):
    await start(dut)
    await write(dut, MTIME, 0)
    await write(dut, MTIMECMP, 10)
    await cycles(dut, 25)          # mtime is now well past mtimecmp
    for i in range(5):
        value = await mtip(dut)
        assert value == 1, f"MTIP dropped {i} cycles after the check started, while mtime > mtimecmp"


@cocotb.test()
async def test_mtimecmp_written_in_the_past(dut):
    await start(dut)
    await write(dut, MTIME, 1000)
    await write(dut, MTIMECMP, 500)   # software sets a compare value already passed
    await cycles(dut, 2)
    value = await mtip(dut)
    assert value == 1, "MTIP not pending although mtime is already past mtimecmp"
