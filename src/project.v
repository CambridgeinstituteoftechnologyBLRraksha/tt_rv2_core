`default_nettype none

module tt_um_riscv_core (
    input  wire [7:0] ui_in,    // [2:0]: debug_sel, [4:3]: byte_sel
    output wire [7:0] uo_out,   // 8-bit debug output
    input  wire [7:0] uio_in,   // Unused inputs
    output wire [7:0] uio_out,  // uio_out[0] = heartbeat signal
    output wire [7:0] uio_oe,   // Pin directions (1 = output, 0 = input)
    input  wire       ena,      // Tiny Tapeout enable signal
    input  wire       clk,      // System clock
    input  wire       rst_n     // Active-low reset
);

    wire reset = !rst_n;
    wire heartbeat;

    assign uio_oe  = 8'b00000001; 
    assign uio_out = {7'b0000000, heartbeat};

    riscv_core u_core (
        .clk       (clk),
        .reset     (reset),
        .debug_sel (ui_in[2:0]),
        .byte_sel  (ui_in[4:3]),
        .debug_out (uo_out),
        .heartbeat (heartbeat)
    );

endmodule
