`timescale 1ns / 1ps

module r4_div_top #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    input  wire                 is_8,     // Mode selector flag
    input  wire                 is_16,    // Mode selector flag
    input  wire                 is_32,    // Mode selector flag
    input  wire [WIDTH-1:0]     x_in,     // MODIFIED: Changed from x_norm to x_in
    input  wire [WIDTH-1:0]     y_in,     // MODIFIED: Changed from y_norm to y_in
    
    output wire [WIDTH-1:0]     q_out,
    output wire [WIDTH-1:0]     rem_out,
    output wire                 done
);

    // Internal wires connecting Controller and Datapath
    wire load_D, load_w, sel2, sel3;
    wire OTFC_clr, OTFC_en;
    
    // NEW: Wires for Pre-processing unit
    wire ld;            
    wire shift_en_4;    
    wire find;          

    r4_div_controller CONTROLLER (
        .clk(clk),
        .rst(rst),
        .start(start),
        .is_8(is_8),
        .is_16(is_16),
        .is_32(is_32),
        .find(find),            // NEW
        .ld(ld),                // NEW
        .shift_en_4(shift_en_4),// NEW
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
        .rst(rst),              // MODIFIED: Added missing reset
        .x_in(x_in),            // MODIFIED
        .y_in(y_in),            // MODIFIED
        .ld(ld),                // NEW
        .sh_en(shift_en_4),     // NEW: Connected shift_en_4 to sh_en
        .load_D(load_D),
        .load_w(load_w),
        .sel2(sel2),
        .sel3(sel3),
        .OTFC_clr(OTFC_clr),
        .OTFC_en(OTFC_en),
        .find(find),            // NEW
        .q_out(q_out),
        .rem_out(rem_out)
    );

endmodule