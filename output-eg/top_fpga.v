`timescale 1ns / 1ps

// =============================================================================
// top_fpga.v — FPGA Top-Level
// Regex count: 6
//
// Architecture:
//   uart_rx → uart_rx_fifo → Control FSM → top (NFA engine)
//                                         → uart_tx → host PC
//
// UART response packet (one line per newline received from host):
//   "MATCH=<6-bit binary> BYTES=<8 hex> HITS=<4 hex per regex,comma-sep>\r\n"
//
// Send '?' (0x3F) to query counters without feeding the NFA.
// =============================================================================

module top_fpga #(
    parameter NUM_REGEX    = 6,
    parameter CLKS_PER_BIT = 868   // 100 MHz / 115200 baud
)(
    input  wire clk,
    input  wire rst_btn,
    input  wire uart_rx_pin,
    output wire uart_tx_pin,
    output reg  [5:0] match_leds
);

    // UART RX
    wire [7:0] rx_data;
    wire       rx_ready;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_rx_inst (
        .clk     (clk),
        .rx      (uart_rx_pin),
        .rx_data (rx_data),
        .rx_ready(rx_ready)
    );

    // Input FIFO
    wire [7:0] fifo_rd_data;
    wire       fifo_empty;
    wire       fifo_full;
    reg        fifo_rd_en = 1'b0;

    uart_rx_fifo #(.DEPTH_LOG2(4)) rx_fifo (
        .clk    (clk),
        .rst    (rst_btn),
        .wr_data(rx_data),
        .wr_en  (rx_ready && !fifo_full),
