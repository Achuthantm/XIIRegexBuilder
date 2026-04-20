`timescale 1ns / 1ps

module tb_top;
    reg clk, en, rst, start, end_of_str;
    reg [7:0] char_in;
    wire [6:0] match_bus;
    wire [6:0] active_bus;

    top uut (.clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match_bus(match_bus), .active_bus(active_bus));

    always #5 clk = ~clk;

    initial begin
        // synthesis translate_off
        `ifndef SYNTHESIS
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
        `endif
        // synthesis translate_on

        clk = 0; en = 1; rst = 1; start = 0; end_of_str = 0; char_in = 0;
        #20 rst = 0; #10;

        // Test case 0: "cat"
        start = 1; #10 start = 0;
        char_in = 8'h63; #10;
        char_in = 8'h61; #10;
        char_in = 8'h74; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 0 ('cat') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 0 ('cat') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 1: "dog"
        start = 1; #10 start = 0;
        char_in = 8'h64; #10;
        char_in = 8'h6f; #10;
        char_in = 8'h67; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 1 ('dog') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 1 ('dog') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 2: "tomcat"
        start = 1; #10 start = 0;
        char_in = 8'h74; #10;
        char_in = 8'h6f; #10;
        char_in = 8'h6d; #10;
        char_in = 8'h63; #10;
        char_in = 8'h61; #10;
        char_in = 8'h74; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 2 ('tomcat') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 2 ('tomcat') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 3: "cot"
        start = 1; #10 start = 0;
        char_in = 8'h63; #10;
        char_in = 8'h6f; #10;
        char_in = 8'h74; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 3 ('cot') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 3 ('cot') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 4: "cut"
        start = 1; #10 start = 0;
        char_in = 8'h63; #10;
        char_in = 8'h75; #10;
        char_in = 8'h74; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 4 ('cut') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 4 ('cut') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 5: "ct"
        start = 1; #10 start = 0;
        char_in = 8'h63; #10;
        char_in = 8'h74; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 5 ('ct') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 5 ('ct') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 6: "doog"
        start = 1; #10 start = 0;
        char_in = 8'h64; #10;
        char_in = 8'h6f; #10;
        char_in = 8'h6f; #10;
        char_in = 8'h67; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 6 ('doog') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 6 ('doog') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 7: "dg"
        start = 1; #10 start = 0;
        char_in = 8'h64; #10;
        char_in = 8'h67; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 7 ('dg') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 7 ('dg') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 8: "beep"
        start = 1; #10 start = 0;
        char_in = 8'h62; #10;
        char_in = 8'h65; #10;
        char_in = 8'h65; #10;
        char_in = 8'h70; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 8 ('beep') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 8 ('beep') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 9: "bep"
        start = 1; #10 start = 0;
        char_in = 8'h62; #10;
        char_in = 8'h65; #10;
        char_in = 8'h70; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 9 ('bep') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 9 ('bep') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 10: "bp"
        start = 1; #10 start = 0;
        char_in = 8'h62; #10;
        char_in = 8'h70; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 10 ('bp') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 10 ('bp') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 11: "fly"
        start = 1; #10 start = 0;
        char_in = 8'h66; #10;
        char_in = 8'h6c; #10;
        char_in = 8'h79; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 11 ('fly') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 11 ('fly') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 12: "fy"
        start = 1; #10 start = 0;
        char_in = 8'h66; #10;
        char_in = 8'h79; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 12 ('fy') matches expected mask 0000000");
        end else begin
            $display("FAIL: Test case 12 ('fy') expected 0000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 13: "apple"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h70; #10;
        char_in = 8'h70; #10;
        char_in = 8'h6c; #10;
        char_in = 8'h65; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 7'b0000000) begin
            $display("PASS: Test case 13 ('apple') matches expected mask 0000000");
