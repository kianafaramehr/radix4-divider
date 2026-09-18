`timescale 1ns / 1ps

// =====================================================================
// MODULE: r4_div_top
// DESCRIPTION: Top-level module for the 32-bit Radix-4 SRT Divider.
// Integrates the input isolating wrapper, FSM controller, and the 
// main processing datapath.
// =====================================================================
module r4_div_top #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    
    input  wire [WIDTH-1:0]     x_in,     // Dividend input from bus
    input  wire [WIDTH-1:0]     y_in,     // Divisor input from bus
    
    output wire [WIDTH-1:0]     q_out,    // Final quotient
    output wire [WIDTH-1:0]     rem_out,  // Final remainder
    output wire                 done      // Operation complete flag
);

    // ==========================================
    // Internal Wires
    // ==========================================
    wire [WIDTH-1:0] x_abs_wire;
    wire [WIDTH-1:0] y_abs_wire;
    wire             final_q_sign_wire;
    wire             final_r_sign_wire;

    // Control signals
    wire ld_in, load_D, load_w, sel2, sel3;
    wire OTFC_clr, OTFC_en;
    wire ld, shift_en_4, find;          
    wire [4:0] n_iters; 
    wire load_post, en_post, post_coarse_zero;

    // ==========================================
    // 1. Input Wrapper Unit
    // ==========================================
    input_wrapper #(WIDTH) INPUT_UNIT (
        .clk(clk),
        .rst(rst),
        .ld_in(ld_in),             
        .x_in(x_in),
        .y_in(y_in),
        .x_abs(x_abs_wire),        
        .y_abs(y_abs_wire),        
        .final_q_sign(final_q_sign_wire), 
        .final_r_sign(final_r_sign_wire)  
    );

    // ==========================================
    // 2. Control Unit (FSM)
    // Manages datapath pipeline and dynamic iterations.
    // ==========================================
    r4_div_controller CONTROLLER (
        .clk(clk),
        .rst(rst),
        .start(start),
        .find(find),
        .n_iters(n_iters),      
        .post_coarse_zero(post_coarse_zero), 
        .ld_in(ld_in),             
        .ld(ld),
        .shift_en_4(shift_en_4),
        .load_D(load_D),
        .load_w(load_w),
        .sel2(sel2),
        .sel3(sel3),
        .OTFC_clr(OTFC_clr),
        .OTFC_en(OTFC_en),
        .load_post(load_post),     
        .en_post(en_post),         
        .done(done)
    );

    // ==========================================
    // 3. Main Datapath Unit 
    // Executes SRT Radix-4 division on absolute values.
    // ==========================================
    r4_div_datapath #(WIDTH) DATAPATH (
        .clk(clk),
        .rst(rst),
        .x_in(x_abs_wire),      
        .y_in(y_abs_wire),      
        .final_q_sign(final_q_sign_wire), 
        .final_r_sign(final_r_sign_wire), 
        .ld(ld),
        .sh_en(shift_en_4),
        .load_D(load_D),
        .load_w(load_w),
        .sel2(sel2),
        .sel3(sel3),
        .OTFC_clr(OTFC_clr),
        .OTFC_en(OTFC_en),
        .load_post(load_post),     
        .en_post(en_post),         
        .post_coarse_zero(post_coarse_zero), 
        .find(find),
        .n_iters(n_iters),      
        .q_out(q_out),            
        .rem_out(rem_out)         
    );

endmodule