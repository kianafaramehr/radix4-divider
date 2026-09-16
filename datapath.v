// =====================================================================
// MODULE: Pre-Processing Unit
// =====================================================================
module r4_div_preprocess #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 ld,
    input  wire                 sh_en,
    input  wire [WIDTH-1:0]     x_in,
    input  wire [WIDTH-1:0]     y_in,
    output wire                 find,
    output wire [4:0]           n_iters,
    output wire [4:0]           m_total,
    output wire [WIDTH-1:0]     y_norm,
    output wire [WIDTH+5:0]     x_shifted_wide
);
    wire [WIDTH-1:0] y_coarse;
    wire [1:0]       pos;
    wire [1:0]       fine_shift_amt;
    reg  [2:0]       coarse_cycles; 

    divisor_shift_register #(WIDTH) Y_COARSE_REG (
        .clk(clk), .rst(rst), .ld(ld), .shift_en_4(sh_en),
        .d_in(y_in), .q(y_coarse)
    );

    pe_4bit ENCODER (
        .in(y_coarse[WIDTH-1 : WIDTH-4]), 
        .pos(pos), 
        .find(find)
    );

    assign fine_shift_amt = ~pos;

    fine_shifter_0_to_3 Y_FINE_SHIFTER (
        .d_in(y_coarse), .shift_amt(fine_shift_amt), .d_out(y_norm)
    );

    always @(posedge clk) begin
        if (ld) begin
            coarse_cycles <= 3'd0;       
        end else if (sh_en) begin
            coarse_cycles <= coarse_cycles + 1'b1; 
        end
    end

    assign m_total = {coarse_cycles, fine_shift_amt};
    
    // Calculate dynamic iterations (N)
    assign n_iters = (({1'b0, m_total} + 6'd1) >> 1) + 5'd1;

    // Shift X into 38-bit wide format based on LSB of m_total
    wire s = m_total[0]; 
    mux_2_to_1 #(WIDTH+6) X_PREP_MUX (
        .i0({5'b00000, x_in, 1'b0}), // Shift X by 1 (X/4)
        .i1({6'b000000, x_in}),      // No shift (X/8)
        .sel(s),           
        .y(x_shifted_wide)      
    );
endmodule

// =====================================================================
// MODULE: Radix-4 SRT Core Unit
// =====================================================================
module r4_div_core #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 load_D,
    input  wire                 load_w,
    input  wire                 sel2,
    input  wire                 sel3,
    input  wire                 OTFC_clr,
    input  wire                 OTFC_en,
    input  wire [WIDTH-1:0]     y_norm,
    input  wire [WIDTH+5:0]     x_shifted_wide,
    output wire                 rem_sign,
    output wire [WIDTH-1:0]     otfc_q,
    output wire [WIDTH-1:0]     otfc_qm,
    output wire [WIDTH+5:0]     raw_rem
);
    wire [WIDTH-1:0] reg_d_out;
    wire [WIDTH+5:0] reg_wc_out, reg_ws_out;
    wire [WIDTH+5:0] csa_wc_nxt, csa_ws_nxt;
    wire [WIDTH+5:0] wc_mux_out, ws_mux_out;
    wire [2:0]       q_next;
    wire [WIDTH+5:0] mux_3_out;

    register #(WIDTH) REG_D (
        .d_in(y_norm), .sclr(1'b0), .ld(load_D), .clk(clk), .q(reg_d_out)
    );

    mux_2_to_1 #(WIDTH+6) INIT_WC_MUX (
        .i0({(WIDTH+6){1'b0}}), .i1(csa_wc_nxt), .sel(sel2), .y(wc_mux_out)
    );
    
    mux_2_to_1 #(WIDTH+6) INIT_WS_MUX (
        .i0(x_shifted_wide), .i1(csa_ws_nxt), .sel(sel3), .y(ws_mux_out)
    );

    register #(WIDTH+6) REG_WC (
        .d_in(wc_mux_out), .sclr(1'b0), .ld(load_w), .clk(clk), .q(reg_wc_out)
    );
    register #(WIDTH+6) REG_WS (
        .d_in(ws_mux_out), .sclr(1'b0), .ld(load_w), .clk(clk), .q(reg_ws_out)
    );

    // Extract y_hat for Q_SEL (38-bit datapath -> bits 35:29)
    wire [6:0] y_hat = reg_wc_out[35 : 29] + reg_ws_out[35 : 29];

    q_sel_structural Q_SEL (
        .divisor_idx(reg_d_out[WIDTH-2 : WIDTH-4]), 
        .y_hat(y_hat), 
        .q_next(q_next)
    );

    // Align Y to 38 bits
    wire [WIDTH+5:0] y_aligned = {3'b000, reg_d_out, 3'b000};

    mux_3_to_1 #(WIDTH+6) MUX_3 (
        .i0({(WIDTH+6){1'b0}}), 
        .i1(y_aligned), 
        .i2({2'b00, reg_d_out, 4'b0000}), 
        .sel(q_next[1:0]), 
        .y(mux_3_out)
    );

    add_sub_csa #(WIDTH+6) LOOP_ADDER (
        .wc_in({reg_wc_out[WIDTH+3:0], 2'b00}), 
        .ws_in({reg_ws_out[WIDTH+3:0], 2'b00}),
        .mux_in(mux_3_out), 
        .op_sign(~q_next[2]), 
        .wc_out(csa_wc_nxt), 
        .ws_out(csa_ws_nxt)
    );

    otfc_block #(WIDTH) OTFC (
        .clk(clk), .clr(OTFC_clr), .en(OTFC_en), .q_next(q_next), 
        .Q(otfc_q), .QM(otfc_qm)
    );
    
    termination_block #(WIDTH) TERMINATION (
        .wc_final(reg_wc_out), 
        .ws_final(reg_ws_out), 
        .divisor_aligned(y_aligned), 
        .true_rem(raw_rem),     
        .rem_sign(rem_sign)
    );
endmodule

// =====================================================================
// MODULE: Post-Processing Unit
// =====================================================================
module r4_div_postprocess #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 load_post,
    input  wire                 en_post,
    input  wire [4:0]           m_total,
    input  wire                 rem_sign,
    input  wire [WIDTH-1:0]     otfc_q,
    input  wire [WIDTH-1:0]     otfc_qm,
    input  wire [WIDTH+5:0]     raw_rem,
    output wire                 post_coarse_zero,
    output wire [WIDTH-1:0]     q_out,
    output wire [WIDTH-1:0]     rem_out
);
    // --- Q Path ---
    assign q_out = rem_sign ? otfc_qm : otfc_q;
    
    // --- R Path ---
    // Compensation shift for remainder
    wire [5:0] total_shift = {1'b0, m_total} + 6'd3; 
    
    wire [3:0] coarse_cnt_val = total_shift[5:2]; 
    wire [1:0] fine_shift_val = total_shift[1:0]; 
    
    wire [3:0] post_counter_out;
    down_counter #(4) POST_COUNTER (
        .clk(clk),
        .ld(load_post),
        .en(en_post),
        .d_in(coarse_cnt_val),
        .q(post_counter_out)
    );
    assign post_coarse_zero = (post_counter_out == 4'd0);
    
    wire [WIDTH+5:0] sh_reg_out;
    remainder_shift_register #(WIDTH+6) REM_SH_REG (
        .clk(clk),
        .rst(rst),
        .ld(load_post),
        .en(en_post),
        .d_in(raw_rem),
        .q(sh_reg_out)
    );
    
    wire [WIDTH+5:0] fine_mux_out;
    mux_4_to_1 #(WIDTH+6) FINE_REM_MUX (
        .i0(sh_reg_out),
        .i1({1'b0, sh_reg_out[WIDTH+5:1]}),
        .i2({2'b00, sh_reg_out[WIDTH+5:2]}),
        .i3({3'b000, sh_reg_out[WIDTH+5:3]}),
        .sel(fine_shift_val),
        .y(fine_mux_out)
    );

    assign rem_out = fine_mux_out[WIDTH-1:0];
endmodule

// =====================================================================
// MAIN DATAPATH MODULE (Wrapper)
// =====================================================================
module r4_div_datapath #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire                 rst,         
    
    input  wire [WIDTH-1:0]     x_in,      
    input  wire [WIDTH-1:0]     y_in,      

    input  wire                 ld,          
    input  wire                 sh_en,       
    input  wire                 load_D,        
    input  wire                 load_w,     
    input  wire                 sel2,
    input  wire                 sel3,
    input  wire                 OTFC_clr,    
    input  wire                 OTFC_en,
    
    input  wire                 load_post,
    input  wire                 en_post,
    output wire                 post_coarse_zero,

    output wire                 find,        
    output wire [4:0]           n_iters,     

    output wire [WIDTH-1:0]     q_out,       
    output wire [WIDTH-1:0]     rem_out      
);
    // Internal interconnect wires
    wire [4:0]       m_total;
    wire [WIDTH-1:0] y_norm;
    wire [WIDTH+5:0] x_shifted_wide;
    wire             rem_sign;
    wire [WIDTH-1:0] otfc_q;
    wire [WIDTH-1:0] otfc_qm;
    wire [WIDTH+5:0] raw_rem;

    r4_div_preprocess #(WIDTH) PREPROCESS_UNIT (
        .clk(clk),
        .rst(rst),
        .ld(ld),
        .sh_en(sh_en),
        .x_in(x_in),
        .y_in(y_in),
        .find(find),
        .n_iters(n_iters),
        .m_total(m_total),
        .y_norm(y_norm),
        .x_shifted_wide(x_shifted_wide)
    );

    r4_div_core #(WIDTH) CORE_UNIT (
        .clk(clk),
        .load_D(load_D),
        .load_w(load_w),
        .sel2(sel2),
        .sel3(sel3),
        .OTFC_clr(OTFC_clr),
        .OTFC_en(OTFC_en),
        .y_norm(y_norm),
        .x_shifted_wide(x_shifted_wide),
        .rem_sign(rem_sign),
        .otfc_q(otfc_q),
        .otfc_qm(otfc_qm),
        .raw_rem(raw_rem)
    );

    r4_div_postprocess #(WIDTH) POSTPROCESS_UNIT (
        .clk(clk),
        .rst(rst),
        .load_post(load_post),
        .en_post(en_post),
        .m_total(m_total),
        .rem_sign(rem_sign),
        .otfc_q(otfc_q),
        .otfc_qm(otfc_qm),
        .raw_rem(raw_rem),
        .post_coarse_zero(post_coarse_zero),
        .q_out(q_out),
        .rem_out(rem_out)
    );

endmodule