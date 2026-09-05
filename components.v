module register #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] d_in,
    input  wire             sclr,
    input  wire             ld,
    input  wire             clk,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (sclr)
            q <= 0;
        else if (ld)
            q <= d_in;
    end
endmodule

module down_counter #(parameter WIDTH = 5) (
    input  wire             clk,
    input  wire             ld,     // Load enable
    input  wire             en,     // Count down enable
    input  wire [WIDTH-1:0] d_in,   // Dynamic initialization value
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (ld)
            q <= d_in;
        else if (en)
            q <= q - 1;
    end
endmodule

module mux_2_to_1 #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] i0,
    input  wire [WIDTH-1:0] i1,
    input  wire             sel,
    output wire [WIDTH-1:0] y
);
    assign y = sel ? i1 : i0;
endmodule

module mux_3_to_1 #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] i0,
    input  wire [WIDTH-1:0] i1,
    input  wire [WIDTH-1:0] i2,
    input  wire [1:0]       sel,
    output wire [WIDTH-1:0] y
);
    assign y = (sel == 2'b10) ? i2 :
               (sel == 2'b01) ? i1 : i0;
endmodule

module q_sel_structural (
    input  wire [2:0] divisor_idx, 
    input  wire [6:0] y_hat,       
    output wire [2:0] q_next       
);
    // --- STAGE 1: SIGN SPLIT & INVERSION ---
    // Declarations
    wire       is_neg;
    wire       is_pos;
    wire [5:0] w;

    // Assignments
    assign is_neg = y_hat[6];
    assign is_pos = ~y_hat[6];
    assign w      = ~y_hat[5:0];

    // --- STAGE 2: THRESHOLD GENERATION ---
    // Declarations for Positive Thresholds
    wire p_geq_4, p_geq_6, p_geq_8, p_geq_12, p_geq_14;
    wire p_geq_15, p_geq_16, p_geq_18, p_geq_20, p_geq_24;

    // Declarations for Negative Thresholds
    wire n_leq_m5, n_leq_m7, n_leq_m9, n_leq_m14, n_leq_m16;
    wire n_leq_m17, n_leq_m19, n_leq_m21, n_leq_m23, n_leq_m25;

    // Assignments for Positive Thresholds
    assign p_geq_4  = y_hat[5] | y_hat[4] | y_hat[3] | y_hat[2];
    assign p_geq_6  = y_hat[5] | y_hat[4] | y_hat[3] | (y_hat[2] & y_hat[1]);
    assign p_geq_8  = y_hat[5] | y_hat[4] | y_hat[3];
    assign p_geq_12 = y_hat[5] | y_hat[4] | (y_hat[3] & y_hat[2]);
    assign p_geq_14 = y_hat[5] | y_hat[4] | (y_hat[3] & y_hat[2] & y_hat[1]);
    assign p_geq_15 = y_hat[5] | y_hat[4] | (y_hat[3] & y_hat[2] & y_hat[1] & y_hat[0]);
    assign p_geq_16 = y_hat[5] | y_hat[4]; 
    assign p_geq_18 = y_hat[5] | (y_hat[4] & (y_hat[3] | y_hat[2] | y_hat[1]));
    assign p_geq_20 = y_hat[5] | (y_hat[4] & (y_hat[3] | y_hat[2]));
    assign p_geq_24 = y_hat[5] | (y_hat[4] & y_hat[3]);

    // Assignments for Negative Thresholds
    assign n_leq_m5  = w[5] | w[4] | w[3] | w[2];
    assign n_leq_m7  = w[5] | w[4] | w[3] | (w[2] & w[1]);
    assign n_leq_m9  = w[5] | w[4] | w[3];
    assign n_leq_m14 = w[5] | w[4] | (w[3] & w[2] & (w[1] | w[0]));
    assign n_leq_m16 = w[5] | w[4] | (w[3] & w[2] & w[1] & w[0]);
    assign n_leq_m17 = w[5] | w[4];
    assign n_leq_m19 = w[5] | (w[4] & (w[3] | w[2] | w[1]));
    assign n_leq_m21 = w[5] | (w[4] & (w[3] | w[2]));
    assign n_leq_m23 = w[5] | (w[4] & (w[3] | (w[2] & w[1])));
    assign n_leq_m25 = w[5] | (w[4] & w[3]);

    // --- STAGE 3: PRIORITY DECODING PER BRANCH ---
    wire [2:0] b8, b9, b10, b11, b12, b13, b14, b15;

    assign b8[2] = is_neg;
    assign b8[1] = (is_pos & p_geq_12) | (is_neg & n_leq_m14);
    assign b8[0] = (is_pos & p_geq_4 & ~p_geq_12) | (is_neg & n_leq_m5 & ~n_leq_m14);

    assign b9[2] = is_neg;
    assign b9[1] = (is_pos & p_geq_14) | (is_neg & n_leq_m16);
    assign b9[0] = (is_pos & p_geq_4 & ~p_geq_14) | (is_neg & n_leq_m7 & ~n_leq_m16);

    assign b10[2] = is_neg;
    assign b10[1] = (is_pos & p_geq_15) | (is_neg & n_leq_m17);
    assign b10[0] = (is_pos & p_geq_4 & ~p_geq_15) | (is_neg & n_leq_m7 & ~n_leq_m17);

    assign b11[2] = is_neg;
    assign b11[1] = (is_pos & p_geq_16) | (is_neg & n_leq_m19);
    assign b11[0] = (is_pos & p_geq_4 & ~p_geq_16) | (is_neg & n_leq_m7 & ~n_leq_m19);

    assign b12[2] = is_neg;
    assign b12[1] = (is_pos & p_geq_18) | (is_neg & n_leq_m21);
    assign b12[0] = (is_pos & p_geq_6 & ~p_geq_18) | (is_neg & n_leq_m9 & ~n_leq_m21);

    assign b13[2] = is_neg;
    assign b13[1] = (is_pos & p_geq_20) | (is_neg & n_leq_m21);
    assign b13[0] = (is_pos & p_geq_6 & ~p_geq_20) | (is_neg & n_leq_m9 & ~n_leq_m21);

    assign b14[2] = is_neg;
    assign b14[1] = (is_pos & p_geq_20) | (is_neg & n_leq_m23);
    assign b14[0] = (is_pos & p_geq_8 & ~p_geq_20) | (is_neg & n_leq_m9 & ~n_leq_m23);

    assign b15[2] = is_neg;
    assign b15[1] = (is_pos & p_geq_24) | (is_neg & n_leq_m25);
    assign b15[0] = (is_pos & p_geq_8 & ~p_geq_24) | (is_neg & n_leq_m9 & ~n_leq_m25);

    // --- STAGE 4: STATIC 8-TO-1 MUX ---
    assign q_next = (divisor_idx == 3'b000) ? b8  :
                    (divisor_idx == 3'b001) ? b9  :
                    (divisor_idx == 3'b010) ? b10 :
                    (divisor_idx == 3'b011) ? b11 :
                    (divisor_idx == 3'b100) ? b12 :
                    (divisor_idx == 3'b101) ? b13 :
                    (divisor_idx == 3'b110) ? b14 : b15 ;
endmodule

module adder #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             ci,
    output wire             co,
    output wire [WIDTH-1:0] s
);
    assign {co, s} = a + b + ci;
endmodule

module csa #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    output wire [WIDTH-1:0] sv,
    output wire [WIDTH-1:0] cv
);
    assign sv = a ^ b ^ c;
    assign cv = ((a & b) | (a & c) | (b & c));
endmodule

module add_sub_csa #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] wc_in,      
    input  wire [WIDTH-1:0] ws_in,      
    input  wire [WIDTH-1:0] mux_in,     
    input  wire             op_sign,    
    output wire [WIDTH-1:0] wc_out,     
    output wire [WIDTH-1:0] ws_out      
);
    reg [WIDTH-1:0] operand;

    // Explicit sensitivity list
    always @(op_sign or mux_in) begin
        if (op_sign == 1'b0) begin
            operand = mux_in;
        end else begin
            operand = ~mux_in;
        end
    end

    wire [WIDTH-1:0] csa_cv;
    csa #(WIDTH) internal_csa (
        .a(wc_in),
        .b(ws_in),
        .c(operand),
        .sv(ws_out),    
        .cv(csa_cv)     
    );

    assign wc_out = {csa_cv[WIDTH-2:0], op_sign};
endmodule

module termination_block #(parameter WIDTH = 32) (
    input  wire [WIDTH+2:0] wc_final,
    input  wire [WIDTH+2:0] ws_final,
    input  wire [WIDTH-1:0] divisor,
    output wire [WIDTH-1:0] true_rem,
    output wire             rem_sign
);
    wire [WIDTH+2:0] raw_rem_35;
    
    adder #(WIDTH+3) assimilation_cpa (
        .a(wc_final),
        .b(ws_final),
        .ci(1'b0),
        .co(),
        .s(raw_rem_35)
    );

    assign rem_sign = raw_rem_35[WIDTH+2];

    wire [WIDTH-1:0] restored_rem;
    
    adder #(WIDTH) correction_adder (
        .a(raw_rem_35[WIDTH-1:0]),
        .b(divisor),
        .ci(1'b0),
        .co(),
        .s(restored_rem)
    );

    assign true_rem = (rem_sign) ? restored_rem : raw_rem_35[WIDTH-1:0];
endmodule

module otfc_block #(parameter WIDTH = 32) (
    input  wire             clk,
    input  wire             clr,
    input  wire             en,
    input  wire [2:0]       q_next,
    output reg  [WIDTH-1:0] Q,
    output reg  [WIDTH-1:0] QM
);
    reg [WIDTH-1:0] next_Q;
    reg [WIDTH-1:0] next_QM;

    // Explicit sensitivity list
    always @(q_next or Q or QM) begin
        case (q_next)
            3'b010: begin 
                next_Q  = {Q[WIDTH-3:0], 2'b10};
                next_QM = {Q[WIDTH-3:0], 2'b01};
            end
            3'b001: begin 
                next_Q  = {Q[WIDTH-3:0], 2'b01};
                next_QM = {Q[WIDTH-3:0], 2'b00};
            end
            3'b000, 3'b100: begin 
                next_Q  = {Q[WIDTH-3:0],  2'b00};
                next_QM = {QM[WIDTH-3:0], 2'b11};
            end
            3'b101: begin 
                next_Q  = {QM[WIDTH-3:0], 2'b11};
                next_QM = {QM[WIDTH-3:0], 2'b10};
            end
            3'b110: begin 
                next_Q  = {QM[WIDTH-3:0], 2'b10};
                next_QM = {QM[WIDTH-3:0], 2'b01};
            end
            default: begin
                next_Q  = Q;
                next_QM = QM;
            end
        endcase
    end

    always @(posedge clk) begin
        if (clr) begin
            Q  <= 0;
            QM <= 0;
        end else if (en) begin
            Q  <= next_Q;
            QM <= next_QM;
        end
    end
endmodule