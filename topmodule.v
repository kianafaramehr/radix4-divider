`timescale 1ns / 1ps

module r4_div_top #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    input  wire                 is_8,     // Mode selector flag
    input  wire                 is_16,    // Mode selector flag
    input  wire                 is_32,    // Mode selector flag
    input  wire [WIDTH-1:0]     x_norm,
    input  wire [WIDTH-1:0]     y_norm,
    
    output wire [WIDTH-1:0]     q_out,
    output wire [WIDTH-1:0]     rem_out,
    output wire                 done
);

    wire load_D, load_w, sel2, sel3;
    wire OTFC_clr, OTFC_en;

    r4_div_controller CONTROLLER (
        .clk(clk),
        .rst(rst),
        .start(start),
        .is_8(is_8),
        .is_16(is_16),
        .is_32(is_32),
        .load_D(load_D),
        .load_w(load_w),
        .sel2(sel2),
        .sel3(sel3),
        .OTFC_clr(OTFC_clr),
        .OTFC_en(OTFC_en),
        .done(done)
    );

    r4_div_datapath #(WIDTH) DATAPATH (
        .clk(clk),
        .x_norm(x_norm),
        .y_norm(y_norm),
        .load_D(load_D),
        .load_w(load_w),
        .sel2(sel2),
        .sel3(sel3),
        .OTFC_clr(OTFC_clr),
        .OTFC_en(OTFC_en),
        .q_out(q_out),
        .rem_out(rem_out)
    );

endmodule