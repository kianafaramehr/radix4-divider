module r4_div_controller (
    input  wire       clk,
    input  wire       rst,                
    input  wire       start,
    input  wire       find,         
    input  wire [4:0] n_iters,      
    
    // Feedback from post-process counter
    input  wire       post_coarse_zero,

    output reg        ld,           
    output reg        shift_en_4,   
    output reg        load_D,       
    output reg        load_w,       
    output reg        sel2,
    output reg        sel3,
    output reg        OTFC_clr,
    output reg        OTFC_en,
    
    // Post-process control signals
    output reg        load_post,
    output reg        en_post,
    output reg        done
);

    localparam [2:0] 
        IDLE         = 3'b000,
        INIT         = 3'b001,
        PREPROCESS   = 3'b010,    
        LOAD_NORM    = 3'b011,    
        DIVIDE       = 3'b100,
        POST_PROCESS = 3'b101,
        DONE         = 3'b110;

    reg [2:0] current_state, next_state;

    reg        Counter_ld;
    reg        Counter_en;
    wire [4:0] itr_cnt_out;
    wire       iterations_eq_0;
    
    down_counter #(5) ITR_CNT (
        .clk(clk),
        .ld(Counter_ld),
        .en(Counter_en),
        .d_in(n_iters),             
        .q(itr_cnt_out)
    );

    assign iterations_eq_0 = (itr_cnt_out == 0);

    always @(posedge clk) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    always @(current_state or start or find or iterations_eq_0 or post_coarse_zero) begin
        next_state = current_state; 
        case (current_state)
            IDLE:         if (start) next_state = INIT;
            INIT:         next_state = PREPROCESS;
            PREPROCESS:   if (find)  next_state = LOAD_NORM; 
            LOAD_NORM:    next_state = DIVIDE;
            DIVIDE:       if (iterations_eq_0) next_state = POST_PROCESS;
            POST_PROCESS: if (post_coarse_zero) next_state = DONE;
            DONE:         if (!start) next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end

    always @(current_state or find or iterations_eq_0 or post_coarse_zero) begin
        // Default Assignments
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
            
            INIT: begin
                ld           = 1'b1; 
                OTFC_clr     = 1'b1; 
            end
            
            PREPROCESS: begin
                if (!find) begin
                    shift_en_4 = 1'b1; 
                end
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
                    // Trigger post-process load in the last core cycle
                    load_post  = 1'b1; 
                end
            end
            
            POST_PROCESS: begin
                if (!post_coarse_zero) begin
                    en_post = 1'b1; // Shift until counter reaches zero
                end
            end
            
            DONE: begin
                done = 1'b1;
            end
        endcase
    end
endmodule