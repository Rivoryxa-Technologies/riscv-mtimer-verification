"""Shared helpers for the mtimer tests: clock, reset, and register access."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer

MTIME, MTIMECMP, DIV = 0, 1, 2


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.we.value = 0
    dut.addr.value = 0
    dut.wdata.value = 0
    dut.halt.value = 0
    dut.rst_n.value = 0
    await Timer(25, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def write(dut, addr, value):
    dut.we.value = 1
    dut.addr.value = addr
    dut.wdata.value = value
    await RisingEdge(dut.clk)
    dut.we.value = 0


async def read(dut, addr):
    dut.addr.value = addr
    await ReadOnly()
    value = int(dut.rdata.value)
    await RisingEdge(dut.clk)
    return value


async def cycles(dut, n):
    for _ in range(n):
        await RisingEdge(dut.clk)


async def mtip(dut):
    await ReadOnly()
    value = int(dut.mtip.value)
    await RisingEdge(dut.clk)
    return value
