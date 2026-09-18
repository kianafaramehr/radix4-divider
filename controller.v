// =====================================================================
// MODULE: r4_div_controller
// DESCRIPTION: Finite State Machine (FSM) for the Radix-4 SRT Divider.
// Controls preprocessing, core iterations, and post-processing steps.
// =====================================================================
module r4_div_controller (
    input  wire       clk,
    input  wire       rst,                
    input  wire       start,
    input  wire       find,             // Indicates MSB '1' found during normalization
    input  wire [4:0] n_iters,          // Dynamic iteration count from datapath
    input  wire       post_coarse_zero, // Flag from post-process shifting counter

    output reg        ld_in,            // Load signal for input isolation registers
    output reg        ld,               // Initialize preprocessing registers
    output reg        shift_en_4,       // Coarse shift enable for normalization
    output reg        load_D,           // Load divisor into core
    output reg        load_w,           // Load working registers (WC, WS)
    output reg        sel2,             // Mux select for WC init
    output reg        sel3,             // Mux select for WS init
    output reg        OTFC_clr,         // Clear OTFC registers
    output reg        OTFC_en,          // Enable OTFC shifting
    output reg        load_post,        // Load post-processing shift counter
    output reg        en_post,          // Enable remainder restoration shift
    output reg        done              // Division complete flag
);

    // FSM States
    localparam [2:0] 
        IDLE         = 3'b000,
        LOAD_SIGN    = 3'b001,    
        INIT         = 3'b010,
        PREPROCESS   = 3'b011,    
        LOAD_NORM    = 3'b100,    
        DIVIDE       = 3'b101,
        POST_PROCESS = 3'b110,
        DONE         = 3'b111;

    reg [2:0] current_state, next_state;

    reg        Counter_ld;
    reg        Counter_en;
    wire [4:0] itr_cnt_out;
    wire       iterations_eq_0;
    
    // Core dynamic iteration counter
    down_counter #(5) ITR_CNT (
        .clk(clk), .ld(Counter_ld), .en(Counter_en),
        .d_in(n_iters), .q(itr_cnt_out)
    );

    assign iterations_eq_0 = (itr_cnt_out == 0);

    // Sequential logic for state transitions
    always @(posedge clk) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    // Combinational logic for next state logic
    always @(*) begin
        next_state = current_state; 
        case (current_state)
            IDLE:         if (start) next_state = LOAD_SIGN;
            LOAD_SIGN:    next_state = INIT; 
            INIT:         next_state = PREPROCESS;
            PREPROCESS:   if (find)  next_state = LOAD_NORM; 
            LOAD_NORM:    next_state = DIVIDE;
            DIVIDE:       if (iterations_eq_0) next_state = POST_PROCESS;
            POST_PROCESS: if (post_coarse_zero) next_state = DONE;
            DONE:         if (!start) next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end

    // Combinational logic for output signals
    always @(*) begin
        // Default assignments to prevent latches
        ld_in        = 1'b0; 
        ld           = 1'b0; 
        shift_en_4   = 1'b0;
        load_D       = 1'b0;
        load_w       = 1'b0;
        sel2         = 1'b0;
        sel3         = 1'b0;
        Counter_ld   = 1'b0; 
        Counter_en   = 1'b0;
        OTFC_clr     = 1'b0;
        OTFC_en      = 1'b0;
        load_post    = 1'b0;
        en_post      = 1'b0;
        done         = 1'b0;

        case (current_state)
            IDLE: begin end
            
            LOAD_SIGN: begin
                ld_in = 1'b1; // Trigger structural input registers
            end

            INIT: begin
                ld           = 1'b1; 
                OTFC_clr     = 1'b1; 
            end
            
            PREPROCESS: begin
                if (!find) shift_en_4 = 1'b1; 
            end

            LOAD_NORM: begin
                load_D       = 1'b1; 
                load_w       = 1'b1; 
                sel2         = 1'b0; 
                sel3         = 1'b0;
                Counter_ld   = 1'b1; 
            end
            
            DIVIDE: begin
                if (!iterations_eq_0) begin
                    load_w     = 1'b1; 
                    sel2       = 1'b1; 
                    sel3       = 1'b1; 
                    Counter_en = 1'b1; 
                    OTFC_en    = 1'b1; 
                end else begin
                    load_post  = 1'b1; // Prepare post-processing shifts
                end
            end
            
            POST_PROCESS: begin
                if (!post_coarse_zero) en_post = 1'b1; 
            end
            
            DONE: begin
                done = 1'b1;
            end
        endcase
    end
endmodule