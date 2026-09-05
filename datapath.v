module r4_div_datapath #(parameter WIDTH = 32) (
    input  wire                 clk,
    input  wire [WIDTH-1:0]     x_norm,      
    input  wire [WIDTH-1:0]     y_norm,      

    // Control signals
    input  wire                 load_D,        
    input  wire                 load_w,     
    input  wire                 sel2,
    input  wire                 sel3,
    input  wire                 OTFC_clr,    
    input  wire                 OTFC_en,     

    // Primary outputs
    output wire [WIDTH-1:0]     q_out,       
    output wire [WIDTH-1:0]     rem_out      
);

    wire [WIDTH-1:0] reg_d_out;
    wire [WIDTH+2:0] reg_wc_out, reg_ws_out;
    wire [WIDTH+2:0] csa_wc_nxt, csa_ws_nxt;
    wire [WIDTH+2:0] wc_mux_out, ws_mux_out;
    
    wire [2:0]       q_next;
    wire [WIDTH+2:0] mux_3_out;
    wire             rem_sign;
    wire [WIDTH-1:0] otfc_q, otfc_qm;

    register #(WIDTH) REG_D (
        .d_in(y_norm), .sclr(1'b0), .ld(load_D), .clk(clk), .q(reg_d_out)
    );

    mux_2_to_1 #(WIDTH+3) INIT_WC_MUX (
        .i0({(WIDTH+3){1'b0}}), .i1(csa_wc_nxt), .sel(sel2), .y(wc_mux_out)
    );
    mux_2_to_1 #(WIDTH+3) INIT_WS_MUX (
        .i0({3'b000, x_norm}), .i1(csa_ws_nxt), .sel(sel3), .y(ws_mux_out)
    );

    register #(WIDTH+3) REG_WC (
        .d_in(wc_mux_out), .sclr(1'b0), .ld(load_w), .clk(clk), .q(reg_wc_out)
    );
    register #(WIDTH+3) REG_WS (
        .d_in(ws_mux_out), .sclr(1'b0), .ld(load_w), .clk(clk), .q(reg_ws_out)
    );

    // Calculate y_hat strictly for the structural Q_SEL block
    wire [6:0] y_hat;
    assign y_hat = reg_wc_out[WIDTH : WIDTH-6] + reg_ws_out[WIDTH : WIDTH-6];

    q_sel_structural Q_SEL (
        .divisor_idx(reg_d_out[WIDTH-2 : WIDTH-4]), 
        .y_hat(y_hat), 
        .q_next(q_next)
    );

    mux_3_to_1 #(WIDTH+3) MUX_3 (
        .i0({(WIDTH+3){1'b0}}), 
        .i1({3'b000, reg_d_out}), 
        .i2({2'b00, reg_d_out, 1'b0}), 
        .sel(q_next[1:0]), 
        .y(mux_3_out)
    );

    add_sub_csa #(WIDTH+3) LOOP_ADDER (
        .wc_in({reg_wc_out[WIDTH:0], 2'b00}), 
        .ws_in({reg_ws_out[WIDTH:0], 2'b00}),
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
        .divisor(reg_d_out), 
        .true_rem(rem_out), 
        .rem_sign(rem_sign)
    );

    assign q_out = rem_sign ? otfc_qm : otfc_q;
endmodule