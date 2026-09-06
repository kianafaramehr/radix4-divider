module r4_div_controller (
    input  wire       clk,
    input  wire       rst,                
    input  wire       start,
    input  wire       is_8,         // Flag for 8-bit mode
    input  wire       is_16,        // Flag for 16-bit mode
    input  wire       is_32,        // Flag for 32-bit mode
    input  wire       find,         // '1' when leading '1' is found in top 4 bits

    output reg        ld,           
    output reg        shift_en_4,   // Enable coarse 4-bit shift in preprocessor
    output reg        load_D,       // Load normalized Divisor into main SRT datapath
    output reg        load_w,       // Load normalized Dividend into main SRT datapath
    output reg        sel2,
    output reg        sel3,
    output reg        OTFC_clr,
    output reg        OTFC_en,
    output reg        done
);

    // Upgraded from 2-bit to 3-bit state encoding to fit new states
    localparam [2:0] 
        IDLE       = 3'b000,
        INIT       = 3'b001,
        PREPROCESS = 3'b010,    
        LOAD_NORM  = 3'b011,    
        DIVIDE     = 3'b100,
        DONE       = 3'b101;

    reg [2:0] current_state, next_state;

    // Internal counter signals for division iterations 
    reg        Counter_ld;
    reg        Counter_en;
    reg  [4:0] cnt_init_val;
    wire [4:0] itr_cnt_out;
    wire       iterations_eq_0;

    // Multiplexer for dynamic iteration counter initialization
    always @(is_8 or is_16 or is_32) begin
        case ({is_8, is_16, is_32})
            3'b100:  cnt_init_val = 5'd4;  // 8-bit operands -> 4 iterations
            3'b010:  cnt_init_val = 5'd8;  // 16-bit operands -> 8 iterations
            3'b001:  cnt_init_val = 5'd16; // 32-bit operands -> 16 iterations
            default: cnt_init_val = 5'd16; // Default safe state
        endcase
    end

    // Instantiating the down-counter for division iterations
    down_counter #(5) ITR_CNT (
        .clk(clk),
        .ld(Counter_ld),
        .en(Counter_en),
        .d_in(cnt_init_val),
        .q(itr_cnt_out)
    );

    // End condition is reaching zero
    assign iterations_eq_0 = (itr_cnt_out == 0);

    // State Register
    always @(posedge clk) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    // Next State Logic (Explicit Sensitivity List)
    always @(current_state or start or find or iterations_eq_0) begin
        next_state = current_state; 
        case (current_state)
            IDLE:       if (start) next_state = INIT;
            INIT:       next_state = PREPROCESS;
            PREPROCESS: if (find)  next_state = LOAD_NORM; 
            LOAD_NORM:  next_state = DIVIDE;
            DIVIDE:     if (iterations_eq_0) next_state = DONE;
            DONE:       if (!start) next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Output Logic (Explicit Sensitivity List)
    always @(current_state or find or iterations_eq_0) begin
        // Default assignments to prevent latches
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
        done         = 1'b0;

        case (current_state)
            IDLE: begin
                // Waiting for start signal
            end
            
            INIT: begin
                ld           = 1'b1; // Load raw inputs into the shift registers
                Counter_ld   = 1'b1; // Setup the division iteration counter early
                OTFC_clr     = 1'b1; // Clear OTFC registers
            end
            
            PREPROCESS: begin
                if (!find) begin
                    shift_en_4 = 1'b1; // Shift both X and Y by 4 bits until '1' is found
                end
            end

            LOAD_NORM: begin
                load_D       = 1'b1; // Grab the normalized divisor
                load_w       = 1'b1; // Grab the normalized dividend
                sel2         = 1'b0; 
                sel3         = 1'b0; 
            end
            
            DIVIDE: begin
                if (!iterations_eq_0) begin
                    load_w     = 1'b1; // Load feedback residual
                    sel2       = 1'b1; // MUX select for residual feedback
                    sel3       = 1'b1; // MUX select for residual feedback
                    Counter_en = 1'b1; // Decrement iteration counter
                    OTFC_en    = 1'b1; // Enable quotient conversion
                end
            end
            
            DONE: begin
                done = 1'b1;
            end
            
            default: begin
                // Defaults apply
            end
        endcase
    end
endmodule