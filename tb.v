`timescale 1ns / 1ns

module tb_r4_div_top;

    localparam WIDTH = 32;
    localparam CLK_PERIOD = 10; // 100 MHz clock
    localparam NUM_TESTS = 10000;

    // Inputs
    reg                 clk;
    reg                 rst;
    reg                 start;
    reg                 is_8;
    reg                 is_16;
    reg                 is_32;
    reg  [WIDTH-1:0]    x_norm;
    reg  [WIDTH-1:0]    y_norm;

    // Outputs
    wire [WIDTH-1:0]    q_out;
    wire [WIDTH-1:0]    rem_out;
    wire                done;

    // Automated Testing Variables
    reg [127:0]         test_memory [0:NUM_TESTS-1]; 
    reg [WIDTH-1:0]     expected_q;
    reg [WIDTH-1:0]     expected_r;
    
    integer             i;
    integer             pass_count;
    integer             fail_count;
    real                success_rate;

    // Instantiate Unit Under Test (UUT)
    r4_div_top #(WIDTH) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .is_8(is_8),
        .is_16(is_16),
        .is_32(is_32),
        .x_norm(x_norm),
        .y_norm(y_norm),
        .q_out(q_out),
        .rem_out(rem_out),
        .done(done)
    );

    // Clock Generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // TASK: Run Verification Batch
    // =========================================================================
    task run_verification_batch;
        input integer mode; // Input mode: 8, 16, or 32
        begin
            // Route the correct flag to the controller
            is_8  = (mode == 8);
            is_16 = (mode == 16);
            is_32 = (mode == 32);
            
            $display("----------------------------------------");
            $display("Testing %0d-bit Data Mode...", mode);
            $display("----------------------------------------");

            for (i = 0; i < NUM_TESTS; i = i + 1) begin
                
                // Parse the 128-bit line
                {x_norm, y_norm, expected_q, expected_r} = test_memory[i];
                
                // Start Handshake
                @(posedge clk);
                start = 1'b1;
                @(posedge clk);
                start = 1'b0;
                
                // Wait for completion
                while (!done) begin
                    @(posedge clk);
                end
                
                // Verify Output
                if (q_out === expected_q && rem_out === expected_r) begin
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                    $display("FAIL [%0d-bit] at vector %0d: X = 0x%08h, Y = 0x%08h", mode, i, x_norm, y_norm);
                    $display("  Expected: Q = 0x%08h, R = 0x%08h", expected_q, expected_r);
                    $display("  Got     : Q = 0x%08h, R = 0x%08h", q_out, rem_out);
                end
                
                // Wait before next division
                repeat(2) @(posedge clk);
            end
        end
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        // Initialize everything to zero
        pass_count = 0;
        fail_count = 0;
        clk    = 0;
        rst    = 1;
        start  = 0;
        is_8   = 0;
        is_16  = 0;
        is_32  = 0;
        x_norm = 0;
        y_norm = 0;

        // Reset the UUT
        repeat (3) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        $display("========================================");
        $display("STARTING FULL MULTI-MODE VERIFICATION...");
        $display("========================================");

        // Phase 1: Test 8-bit mode
        $readmemh("vectors_8.txt", test_memory);
        run_verification_batch(8);

        // Phase 2: Test 16-bit mode
        $readmemh("vectors_16.txt", test_memory);
        run_verification_batch(16);

        // Phase 3: Test 32-bit mode
        $readmemh("vectors_32.txt", test_memory);
        run_verification_batch(32);
        
        // Final Results Calculation
        success_rate = (pass_count * 100.0) / (pass_count + fail_count);
        $display("\n========================================");
        $display("ALL TESTING COMPLETE");
        $display("Total Passed : %0d", pass_count);
        $display("Total Failed : %0d", fail_count);
        $display("Success Rate : %0.2f%%", success_rate);
        $display("========================================");
        
        $stop; // Pause simulation
    end

endmodule
