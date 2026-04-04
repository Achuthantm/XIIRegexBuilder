`timescale 1ns / 1ps

module tb_top;
    reg clk, en, rst, start, end_of_str;
    reg [7:0] char_in;
    wire [5:0] match_bus;

    top uut (.clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match_bus(match_bus));

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

        // Test case 0: "a"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000101) begin
            $display("PASS: Test case 0 ('a') matches expected mask 000101");
        end else begin
            $display("FAIL: Test case 0 ('a') expected 000101, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 1: "b"
        start = 1; #10 start = 0;
        char_in = 8'h62; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000101) begin
            $display("PASS: Test case 1 ('b') matches expected mask 000101");
        end else begin
            $display("FAIL: Test case 1 ('b') expected 000101, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 2: "c"
        start = 1; #10 start = 0;
        char_in = 8'h63; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000000) begin
            $display("PASS: Test case 2 ('c') matches expected mask 000000");
        end else begin
            $display("FAIL: Test case 2 ('c') expected 000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 3: "aa"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h61; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000100) begin
            $display("PASS: Test case 3 ('aa') matches expected mask 000100");
        end else begin
            $display("FAIL: Test case 3 ('aa') expected 000100, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 4: "ab"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000100) begin
            $display("PASS: Test case 4 ('ab') matches expected mask 000100");
        end else begin
            $display("FAIL: Test case 4 ('ab') expected 000100, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 5: "ac"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h63; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000110) begin
            $display("PASS: Test case 5 ('ac') matches expected mask 000110");
        end else begin
            $display("FAIL: Test case 5 ('ac') expected 000110, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 6: "abc"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        char_in = 8'h63; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b010110) begin
            $display("PASS: Test case 6 ('abc') matches expected mask 010110");
        end else begin
            $display("FAIL: Test case 6 ('abc') expected 010110, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 7: "abbc"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        char_in = 8'h62; #10;
        char_in = 8'h63; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000110) begin
            $display("PASS: Test case 7 ('abbc') matches expected mask 000110");
        end else begin
            $display("FAIL: Test case 7 ('abbc') expected 000110, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 8: "abbbc"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        char_in = 8'h62; #10;
        char_in = 8'h62; #10;
        char_in = 8'h63; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000110) begin
            $display("PASS: Test case 8 ('abbbc') matches expected mask 000110");
        end else begin
            $display("FAIL: Test case 8 ('abbbc') expected 000110, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 9: "aaaa"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h61; #10;
        char_in = 8'h61; #10;
        char_in = 8'h61; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000100) begin
            $display("PASS: Test case 9 ('aaaa') matches expected mask 000100");
        end else begin
            $display("FAIL: Test case 9 ('aaaa') expected 000100, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 10: "bbbb"
        start = 1; #10 start = 0;
        char_in = 8'h62; #10;
        char_in = 8'h62; #10;
        char_in = 8'h62; #10;
        char_in = 8'h62; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000100) begin
            $display("PASS: Test case 10 ('bbbb') matches expected mask 000100");
        end else begin
            $display("FAIL: Test case 10 ('bbbb') expected 000100, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 11: "x"
        start = 1; #10 start = 0;
        char_in = 8'h78; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000000) begin
            $display("PASS: Test case 11 ('x') matches expected mask 000000");
        end else begin
            $display("FAIL: Test case 11 ('x') expected 000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 12: "axb"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h78; #10;
        char_in = 8'h62; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b001000) begin
            $display("PASS: Test case 12 ('axb') matches expected mask 001000");
        end else begin
            $display("FAIL: Test case 12 ('axb') expected 001000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 13: "ayb"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h79; #10;
        char_in = 8'h62; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b001000) begin
            $display("PASS: Test case 13 ('ayb') matches expected mask 001000");
        end else begin
            $display("FAIL: Test case 13 ('ayb') expected 001000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 14: "(a|b)"
        start = 1; #10 start = 0;
        char_in = 8'h28; #10;
        char_in = 8'h61; #10;
        char_in = 8'h7c; #10;
        char_in = 8'h62; #10;
        char_in = 8'h29; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b000000) begin
            $display("PASS: Test case 14 ('(a|b)') matches expected mask 000000");
        end else begin
            $display("FAIL: Test case 14 ('(a|b)') expected 000000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 15: "abc"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        char_in = 8'h63; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b010110) begin
            $display("PASS: Test case 15 ('abc') matches expected mask 010110");
        end else begin
            $display("FAIL: Test case 15 ('abc') expected 010110, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 16: "abcd"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        char_in = 8'h63; #10;
        char_in = 8'h64; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b100000) begin
            $display("PASS: Test case 16 ('abcd') matches expected mask 100000");
        end else begin
            $display("FAIL: Test case 16 ('abcd') expected 100000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        // Test case 17: "abce"
        start = 1; #10 start = 0;
        char_in = 8'h61; #10;
        char_in = 8'h62; #10;
        char_in = 8'h63; #10;
        char_in = 8'h65; #10;
        end_of_str = 1; #10;
        // Match output is valid on the cycle immediately following end_of_str assertion
        if (match_bus === 6'b100000) begin
            $display("PASS: Test case 17 ('abce') matches expected mask 100000");
        end else begin
            $display("FAIL: Test case 17 ('abce') expected 100000, got %b", match_bus);
        end
        end_of_str = 0; #10;

        $display("All tests completed.");
        #100; $finish;
    end
endmodule
