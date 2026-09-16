`timescale 1ns / 1ps

module r4_div_top #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    
    input  wire [WIDTH-1:0]     x_in,     
    input  wire [WIDTH-1:0]     y_in,     
    
    output wire [WIDTH-1:0]     q_out,
    output wire [WIDTH-1:0]     rem_out,
    output wire                 done
);

    // ==========================================
    // Internal Wires
    // ==========================================
    // Sign Manager Connections
    wire [WIDTH-1:0] x_abs_wire;
    wire [WIDTH-1:0] y_abs_wire;
    wire [WIDTH-1:0] core_q_wire;
    wire [WIDTH-1:0] core_rem_wire;

    // Controller <-> Datapath Connections
    wire load_D, load_w, sel2, sel3;
    wire OTFC_clr, OTFC_en;
    wire ld, shift_en_4, find;          
    wire [4:0] n_iters; 
    wire load_post;
    wire en_post;
    wire post_coarse_zero;

    // ==========================================
    // 1. Sign Wrapper Unit
    // ==========================================
    sign_manager #(WIDTH) SIGN_UNIT (
        .clk(clk),
        .rst(rst),
        .start(start),
        .x_in(x_in),
        .y_in(y_in),
        .q_out(q_out),
        .rem_out(rem_out),
        .x_abs(x_abs_wire),     
        .y_abs(y_abs_wire),     
        .core_q(core_q_wire),   
        .core_rem(core_rem_wire) 
    );

    // ==========================================
    // 2. Control Unit (FSM)
    // ==========================================
    r4_div_controller CONTROLLER (
        .clk(clk),
        .rst(rst),
        .start(start),
        .find(find),
        .n_iters(n_iters),      
        .post_coarse_zero(post_coarse_zero), 
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
    // 3. Datapath Unit (38-Bit SRT Core)
    // ==========================================
    r4_div_datapath #(WIDTH) DATAPATH (
        .clk(clk),
        .rst(rst),
        .x_in(x_abs_wire),      
        .y_in(y_abs_wire),      
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
        .q_out(core_q_wire),    
        .rem_out(core_rem_wire) 
    );

endmodule