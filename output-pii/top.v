`timescale 1ns / 1ps

module top (
    input  wire       clk,
    input  wire       en,
    input  wire       rst,
    input  wire       start,
    input  wire       end_of_str,
    input  wire [7:0] char_in,
    output wire [6:0] match_bus,
    output wire [6:0] active_bus
);

    nfa_0 inst_0 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[0]), .active(active_bus[0])
    );

    nfa_1 inst_1 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[1]), .active(active_bus[1])
    );

    nfa_2 inst_2 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[2]), .active(active_bus[2])
    );

    nfa_3 inst_3 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[3]), .active(active_bus[3])
    );

    nfa_4 inst_4 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[4]), .active(active_bus[4])
    );

    nfa_5 inst_5 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[5]), .active(active_bus[5])
    );

    nfa_6 inst_6 (
        .clk(clk), .en(en), .rst(rst), .start(start), .end_of_str(end_of_str), .char_in(char_in), .match(match_bus[6]), .active(active_bus[6])
    );

endmodule
