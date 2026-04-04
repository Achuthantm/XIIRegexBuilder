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
        .full   (fifo_full),
        .rd_data(fifo_rd_data),
        .rd_en  (fifo_rd_en),
        .empty  (fifo_empty)
    );

    // NFA Engine
    reg                  nfa_start      = 1'b1;
    reg                  nfa_end_of_str = 1'b0;
    reg  [7:0]           nfa_char_in    = 8'h00;
    reg                  nfa_en         = 1'b0;
    wire [5:0] match_bus;

    top regex_engine (
        .clk        (clk),
        .en         (nfa_en),
        .rst        (rst_btn),
        .start      (nfa_start),
        .end_of_str (nfa_end_of_str),
        .char_in    (nfa_char_in),
        .match_bus  (match_bus)
    );

    // Hardware Counters
    reg [31:0] byte_count = 32'd0;
    // One 16-bit hit counter per regex
    reg [15:0] match_count [0:15];
    integer ci;
    initial begin
        for (ci = 0; ci < 16; ci = ci + 1)
            match_count[ci] = 16'd0;
    end

    // UART TX & Drain Sub-FSM
    localparam TX_BUF_LEN = 128;
    reg [7:0] tx_buf [0:TX_BUF_LEN-1];
    reg [6:0] tx_len  = 7'd0;
    reg [6:0] tx_ptr  = 7'd0;
    reg       tx_send = 1'b0;  // pulse: start draining tx_buf

    wire      tx_busy;
    reg       tx_start_r = 1'b0;
    reg [7:0] tx_data_r  = 8'd0;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx_inst (
        .clk     (clk),
        .rst     (rst_btn),
        .tx_data (tx_data_r),
        .tx_start(tx_start_r),
        .tx_busy (tx_busy),
        .tx      (uart_tx_pin)
    );

    // hex nibble → ASCII character
    function [7:0] hex_char;
        input [3:0] nibble;
        begin
            hex_char = (nibble < 4'd10) ? (8'd48 + nibble) : (8'd55 + nibble);
        end
    endfunction

    localparam TX_IDLE = 2'd0, TX_LOAD = 2'd1, TX_WAIT = 2'd2, TX_NEXT = 2'd3;
    reg [1:0] tx_state = TX_IDLE;

    always @(posedge clk) begin
        tx_start_r <= 1'b0;
