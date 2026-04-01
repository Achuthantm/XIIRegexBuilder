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
