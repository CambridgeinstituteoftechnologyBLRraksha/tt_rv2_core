import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting RISC-V Core gate-level test...")

    # Start a 10 MHz clock (100 ns period)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # Initialize all control inputs
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Assert active-low reset for 10 cycles
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Let the processor run instructions for 100 clock cycles
    await ClockCycles(dut.clk, 100)

    # Sample the debug output port
    # ui_in[2:0] selects PC/debug register, ui_in[4:3] selects byte
    dut.ui_in.value = 0b00000000
    await ClockCycles(dut.clk, 5)

    dut._log.info(f"Processor ran successfully! uo_out = {dut.uo_out.value}")
