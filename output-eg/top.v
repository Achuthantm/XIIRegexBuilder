`timescale 1ns / 1ps

module top (
    input  wire       clk,
    input  wire       en,
    input  wire       rst,
    input  wire       start,
    input  wire       end_of_str,
    input  wire [7:0] char_in,
    output wire [5:0] match_bus
);

