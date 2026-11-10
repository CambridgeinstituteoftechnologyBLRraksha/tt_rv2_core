`default_nettype none
`timescale 1ns/1ps

module riscv_core(
    input  wire        clk,
    input  wire        reset,
    input  wire [2:0]  debug_sel,
    input  wire [1:0]  byte_sel,
    output reg  [7:0]  debug_out,
    output wire        heartbeat
);

    localparam FETCH     = 3'd0,
               DECODE    = 3'd1,
               EXECUTE   = 3'd2,
               MEMORY    = 3'd3,
               WRITEBACK = 3'd4;

    reg [2:0] state;
    reg [31:0] pc;
    wire [31:0] instr;

    // Small synthesizable Data RAM: 16 words (32-bit each)
    reg [31:0] data_mem [0:15];

    // ROM Instruction Memory Function (Hardcoded Demo Program)
    reg [31:0] rom_data;
    always @(*) begin
        case (pc[5:2])
            4'd0: rom_data = 32'h00500093; // addi x1, x0, 5
            4'd1: rom_data = 32'h00a00113; // addi x2, x0, 10
            4'd2: rom_data = 32'h002081b3; // add  x3, x1, x2
            4'd3: rom_data = 32'h00302023; // sw   x3, 0(x0)
            4'd4: rom_data = 32'h00002203; // lw   x4, 0(x0)
            4'd5: rom_data = 32'hfe418ee3; // beq  x3, x4, -4
            default: rom_data = 32'h00000013; // nop
        endcase
    end
    assign instr = rom_data;

    // Register file interface
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [4:0] rd  = instr[11:7];

    wire [6:0] opcode = instr[6:0];
    wire [6:0] funct7 = instr[31:25];

    wire [31:0] rd1, rd2;
    wire [31:0] x3_debug;

    reg        reg_we;
    reg [31:0] write_data;

    register_file rf (
        .clk(clk),
        .reset(reset),
        .we(reg_we),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(write_data),
        .rd1(rd1),
        .rd2(rd2),
        .x3_debug(x3_debug)
    );

    // Immediates
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7],
                         instr[30:25], instr[11:8], 1'b0};

    // ALU
    reg  [3:0]  alu_ctrl;
    wire [31:0] alu_out;
    wire        zero;

    wire [31:0] alu_src2 =
        (opcode == 7'b0010011) ? imm_i :
        (opcode == 7'b0000011) ? imm_i :
        (opcode == 7'b0100011) ? imm_s :
                                 rd2;

    alu alu_unit (
        .a(rd1),
        .b(alu_src2),
        .alu_ctrl(alu_ctrl),
        .result(alu_out),
        .zero(zero)
    );

    // State Machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc      <= 32'd0;
            state   <= FETCH;
            reg_we  <= 1'b0;
        end else begin
            case (state)
                FETCH: begin
                    reg_we <= 1'b0;
                    state  <= DECODE;
                end

                DECODE: begin
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    case (opcode)
                        7'b0110011: begin
                            if (funct7 == 7'b0100000)
                                alu_ctrl <= 4'b0001; // SUB
                            else
                                alu_ctrl <= 4'b0000; // ADD
                        end
                        default: alu_ctrl <= 4'b0000;
                    endcase

                    if (opcode == 7'b1100011) begin
                        if (rd1 == rd2)
                            pc <= pc + imm_b;
                        else
                            pc <= pc + 4;
                        state <= FETCH;
                    end else begin
                        state <= MEMORY;
                    end
                end

                MEMORY: begin
                    if (opcode == 7'b0100011) begin
                        data_mem[alu_out[5:2]] <= rd2;
                    end
                    state <= WRITEBACK;
                end

                WRITEBACK: begin
                    reg_we <= 1'b0;

                    if (opcode == 7'b0110011 || opcode == 7'b0010011) begin
                        write_data <= alu_out;
                        reg_we     <= 1'b1;
                    end
                    else if (opcode == 7'b0000011) begin
                        write_data <= data_mem[alu_out[5:2]];
                        reg_we     <= 1'b1;
                    end

                    if (opcode != 7'b1100011)
                        pc <= pc + 4;

                    state <= FETCH;
                end

                default: state <= FETCH;
            endcase
        end
    end

    assign heartbeat = (state == FETCH);

    // Multiplexer for 8-bit output
    reg [31:0] mux_32;
    always @(*) begin
        case (debug_sel)
            3'd0: mux_32 = pc;
            3'd1: mux_32 = instr;
            3'd2: mux_32 = alu_out;
            3'd3: mux_32 = x3_debug;
            3'd4: mux_32 = data_mem[0];
            default: mux_32 = pc;
        endcase
    end

    always @(*) begin
        case (byte_sel)
            2'b00: debug_out = mux_32[7:0];
            2'b01: debug_out = mux_32[15:8];
            2'b10: debug_out = mux_32[23:16];
            2'b11: debug_out = mux_32[31:24];
        endcase
    end

endmodule

module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;
            4'b0001: result = a - b;
            default: result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0);
endmodule

module register_file(
    input  wire        clk,
    input  wire        reset,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    output wire [31:0] x3_debug
);
    reg [31:0] regs[0:31];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else begin
            if (we && (rd != 5'd0))
                regs[rd] <= wd;
        end
    end

    assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];
    assign x3_debug = regs[3];
endmodule
