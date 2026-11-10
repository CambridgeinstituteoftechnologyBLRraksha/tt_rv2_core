<!---
This file is used to generate your project datasheet. Please fill in the sections below.
-->

## How it works

This project implements a multi-cycle 32-bit RISC-V (RV32I) integer processor core.
It executes instructions directly from a hardcoded internal ROM loop. The core steps through standard Fetch, Decode, Execute, Memory, and Writeback states. An internal multiplexer routes the 32-bit internal registers (PC, instruction, ALU output, and general-purpose registers) out through the 8-bit output bus (`uo_out`) based on selection inputs.

## How to test

1. Apply clock pulses to `clk`.
2. Release reset (`rst_n` = 1).
3. Observe `uio_out[0]` for the heartbeat pulse indicating instruction fetch states.
4. Set `ui_in[2:0]` to choose the signal:
   - `000`: Program Counter (`pc`)
   - `001`: Instruction (`instr`)
   - `010`: ALU result (`alu_out`)
   - `011`: Register `x3` (`x3_debug`)
5. Set `ui_in[4:3]` to select the target byte (`00` for byte 0 up to `11` for byte 3).

## External hardware

None required.
