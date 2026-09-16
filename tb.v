`timescale 1ns / 1ps

module tb_r4_div_top();

    parameter WIDTH = 32;
    localparam CLK_PERIOD = 10;

    reg              clk;
    reg              rst;
    reg              start;
    // Explicitly define as signed for Verilog's internal math operations
    reg  signed [WIDTH-1:0] x_in;
    reg  signed [WIDTH-1:0] y_in;

    wire [WIDTH-1:0] q_out;
    wire [WIDTH-1:0] rem_out;
    wire             done;

    integer total_tests = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;
    integer i;
    
    reg signed [WIDTH-1:0] expected_q;
    reg signed [WIDTH-1:0] expected_rem;

    // Instantiate Top Module
    r4_div_top #(WIDTH) UUT (
        .clk(clk),
        .rst(rst),
        .start(start),
        .x_in(x_in),
        .y_in(y_in),
        .q_out(q_out),
        .rem_out(rem_out),
        .done(done)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test execution task
    task run_test;
        input signed [WIDTH-1:0] test_x;
        input signed [WIDTH-1:0] test_y;
        integer timeout_counter;
        begin
            if (test_y == 0) test_y = 1; // Prevent divide by zero

            // Calculate expected results using Verilog math
            expected_q   = test_x / test_y;
            expected_rem = test_x % test_y;

            @(negedge clk);
            x_in  = test_x;
            y_in  = test_y;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            timeout_counter = 0;
            while (!done && timeout_counter < 100) begin
                @(negedge clk);
                timeout_counter = timeout_counter + 1;
            end

            if (timeout_counter >= 100) begin
                $display("TIMEOUT ERROR: X=%0d, Y=%0d", test_x, test_y);
                failed_tests = failed_tests + 1;
            end else begin
                // Compare hardware outputs with expected results
                if ((q_out !== expected_q) || (rem_out !== expected_rem)) begin
                    failed_tests = failed_tests + 1;
                    $display("FAIL: X=%0d, Y=%0d", test_x, test_y);
                    $display("   Expected: Q = %0d, R = %0d", expected_q, expected_rem);
                    $display("   Hardware: Q = %0d, R = %0d", $signed(q_out), $signed(rem_out));
                end else begin
                    passed_tests = passed_tests + 1;
                end
            end
            total_tests = total_tests + 1;
            
            @(negedge clk);
        end
    endtask

    initial begin
        rst = 1'b1;
        start = 1'b0;
        x_in = 0;
        y_in = 0;

        #(CLK_PERIOD * 5);
        @(negedge clk) rst = 1'b0;
        #(CLK_PERIOD * 2);

        // ==========================================
        // Phase 1: Manual Directed Tests (Corner Cases)
        // ==========================================
        $display("\n--- Running Manual Directed Tests ---");
        run_test(-32'd8,  32'd4);   
        run_test( 32'd29, -32'd3);  
        run_test(-32'd100,-32'd10); 
        run_test( 32'd15,  32'd4);  

        // ==========================================
        // Phase 2: 8-Bit Signed Tests
        // ==========================================
        $display("--- Running 8-Bit Signed Tests ---");
        for (i = 0; i < 500; i = i + 1) begin
            // Range: -127 to +127
            run_test($random % 128, $random % 128);
        end

        // ==========================================
        // Phase 3: 16-Bit Signed Tests
        // ==========================================
        $display("--- Running 16-Bit Signed Tests ---");
        for (i = 0; i < 1000; i = i + 1) begin
            // Range: -32767 to +32767
            run_test($random % 32768, $random % 32768);
        end

        // ==========================================
        // Phase 4: 32-Bit Signed Tests
        // ==========================================
        $display("--- Running 32-Bit Signed Tests ---");
        for (i = 0; i < 2000; i = i + 1) begin
            // Full 32-bit range
            run_test({$random, $random}, {$random, $random});
        end

        // ==========================================
        // Final Summary
        // ==========================================
        $display("\n===================================================");
        $display("                 TEST SUMMARY                      ");
        $display("===================================================");
        $display(" Total Tests Run : %0d", total_tests);
        $display(" Passed Tests    : %0d", passed_tests);
        $display(" Failed Tests    : %0d", failed_tests);
        $display("===================================================\n");

        $stop;
    end

endmodule
