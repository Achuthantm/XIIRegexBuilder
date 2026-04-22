`timescale 1ns / 1ps

// =============================================================================
// top_fpga.v -  FPGA Top-Level
// Regex count: 16
//
// Architecture:
//   uart_rx → uart_rx_fifo → Control FSM → top (NFA engine)
//                                         → uart_tx → host PC
//
// UART response packet (one line per newline received from host):
//   "MATCH=<16-bit binary> BYTES=<8 hex> HITS=<4 hex per regex,comma-sep>\r\n"
//
// Send '?' (0x3F) to query counters without feeding the NFA.
// =============================================================================

module top_fpga #(
    parameter NUM_REGEX    = 16,
    parameter CLKS_PER_BIT = 868   // 100 MHz / 115200 baud
)(
    input  wire clk,
    input  wire rst_btn,
    input  wire uart_rx_pin,
    output wire uart_tx_pin,
    output reg  [15:0] match_leds
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
    wire [15:0] match_bus;

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
        if (rst_btn) begin
            tx_state <= TX_IDLE;
            tx_ptr   <= 7'd0;
        end else begin
            case (tx_state)
                TX_IDLE: if (tx_send) begin tx_ptr <= 7'd0; tx_state <= TX_LOAD; end
                TX_LOAD: if (!tx_busy) begin
                    tx_data_r  <= tx_buf[tx_ptr];
                    tx_start_r <= 1'b1;
                    tx_state   <= TX_WAIT;
                end
                TX_WAIT: if (tx_busy)  tx_state <= TX_NEXT;
                TX_NEXT: if (!tx_busy) begin
                    if (tx_ptr + 1 < tx_len) begin
                        tx_ptr   <= tx_ptr + 1;
                        tx_state <= TX_LOAD;
                    end else
                        tx_state <= TX_IDLE;
                end
            endcase
        end
    end

    // build_response Task
    // Fills tx_buf with the ASCII response packet in one clock cycle.
    // Format: "MATCH=<bits> BYTES=<8hex> HITS=<4hex per regex,csv>\r\n"
    reg [6:0]  bp;         // build pointer (local to task scope)
    reg [15:0] tmp16;
    integer    ri;

    task build_response;
        input [15:0] mbits;
        input [31:0]          bcount;
        integer k;
        begin : build_task
            integer p;
            p = 0;
            // "MATCH="
            tx_buf[p]=8'h4D; p=p+1;  // M
            tx_buf[p]=8'h41; p=p+1;  // A
            tx_buf[p]=8'h54; p=p+1;  // T
            tx_buf[p]=8'h43; p=p+1;  // C
            tx_buf[p]=8'h48; p=p+1;  // H
            tx_buf[p]=8'h3D; p=p+1;  // =
            // match bits, MSB first
            tx_buf[p] = (mbits[15]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[14]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[13]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[12]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[11]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[10]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[9]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[8]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[7]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[6]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[5]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[4]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[3]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[2]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[1]) ? 8'h31 : 8'h30; p=p+1;
            tx_buf[p] = (mbits[0]) ? 8'h31 : 8'h30; p=p+1;
            // " BYTES="
            tx_buf[p]=8'h20; p=p+1;
            tx_buf[p]=8'h42; p=p+1;  // B
            tx_buf[p]=8'h59; p=p+1;  // Y
            tx_buf[p]=8'h54; p=p+1;  // T
            tx_buf[p]=8'h45; p=p+1;  // E
            tx_buf[p]=8'h53; p=p+1;  // S
            tx_buf[p]=8'h3D; p=p+1;  // =
            tx_buf[p]=hex_char(bcount[31:28]); p=p+1;
            tx_buf[p]=hex_char(bcount[27:24]); p=p+1;
            tx_buf[p]=hex_char(bcount[23:20]); p=p+1;
            tx_buf[p]=hex_char(bcount[19:16]); p=p+1;
            tx_buf[p]=hex_char(bcount[15:12]); p=p+1;
            tx_buf[p]=hex_char(bcount[11: 8]); p=p+1;
            tx_buf[p]=hex_char(bcount[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(bcount[ 3: 0]); p=p+1;
            // " HITS="
            tx_buf[p]=8'h20; p=p+1;
            tx_buf[p]=8'h48; p=p+1;  // H
            tx_buf[p]=8'h49; p=p+1;  // I
            tx_buf[p]=8'h54; p=p+1;  // T
            tx_buf[p]=8'h53; p=p+1;  // S
            tx_buf[p]=8'h3D; p=p+1;  // =
            tmp16 = match_count[0];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[1];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[2];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[3];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[4];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[5];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[6];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[7];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[8];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[9];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[10];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[11];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[12];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[13];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[14];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h2C; p=p+1;  // ','
            tmp16 = match_count[15];
            tx_buf[p]=hex_char(tmp16[15:12]); p=p+1;
            tx_buf[p]=hex_char(tmp16[11: 8]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 7: 4]); p=p+1;
            tx_buf[p]=hex_char(tmp16[ 3: 0]); p=p+1;
            tx_buf[p]=8'h0D; p=p+1;  // CR
            tx_buf[p]=8'h0A; p=p+1;  // LF
            tx_len = p[6:0];
        end
    endtask

    // Main Control FSM
    localparam S_IDLE      = 4'd0;
    localparam S_FETCH     = 4'd1;
    localparam S_DECODE    = 4'd2;
    localparam S_CHAR_LOAD = 4'd3;
    localparam S_CHAR_STEP = 4'd4;
    localparam S_EOL_END   = 4'd5;
    localparam S_EOL_MATCH = 4'd6;
    localparam S_EOL_LATCH = 4'd7;
    localparam S_TX_ARM    = 4'd8;
    localparam S_TX_WAIT   = 4'd9;
    localparam S_RESET_NFA = 4'd10;
    localparam S_QUERY_TX  = 4'd11;

    reg [3:0] state = S_RESET_NFA;

    reg [15:0] snap_match = 16'b0;
    reg [31:0]          snap_bytes = 32'd0;
    integer k;

    always @(posedge clk) begin
        tx_send    <= 1'b0;
        fifo_rd_en <= 1'b0;
        nfa_en     <= 1'b0;
        nfa_start  <= 1'b0;

        if (rst_btn) begin
            state      <= S_RESET_NFA;
            match_leds <= 16'b0;
            byte_count <= 32'd0;
            for (k = 0; k < 16; k = k + 1)
                match_count[k] <= 16'd0;
        end else begin
            case (state)

                S_IDLE: begin
                    nfa_end_of_str <= 1'b0;
                    if (!fifo_empty) state <= S_FETCH;
                end

                S_FETCH: begin
                    fifo_rd_en <= 1'b1;
                    state      <= S_DECODE;
                end

                S_DECODE: begin
                    if (fifo_rd_data == 8'h0A || fifo_rd_data == 8'h0D) begin
                        nfa_end_of_str <= 1'b1;
                        state          <= S_EOL_END;
                    end else if (fifo_rd_data == 8'h3F) begin  // '?'
                        state <= S_QUERY_TX;
                    end else begin
                        nfa_char_in <= fifo_rd_data;
                        state       <= S_CHAR_LOAD;
                    end
                end

                S_CHAR_LOAD: state <= S_CHAR_STEP;

                S_CHAR_STEP: begin
                    nfa_en     <= 1'b1;
                    byte_count <= byte_count + 1;
                    state      <= S_IDLE;
                end

                S_EOL_END: begin
                    nfa_en <= 1'b1;
                    state  <= S_EOL_MATCH;
                end

                S_EOL_MATCH: begin
                    nfa_en         <= 1'b1;
                    nfa_end_of_str <= 1'b0;
                    state          <= S_EOL_LATCH;
                end

                S_EOL_LATCH: begin
                    snap_match <= match_bus;
                    snap_bytes <= byte_count;
                    match_leds <= match_bus;
                    for (k = 0; k < 16; k = k + 1)
                        if (match_bus[k]) match_count[k] <= match_count[k] + 16'd1;
                    state <= S_TX_ARM;
                end

                S_TX_ARM: begin
                    build_response(snap_match, snap_bytes);
                    tx_send <= 1'b1;
                    state   <= S_TX_WAIT;
                end

                S_TX_WAIT:
                    if (tx_state == TX_IDLE && !tx_send) state <= S_RESET_NFA;

                S_RESET_NFA: begin
                    nfa_start <= 1'b1;
                    nfa_en    <= 1'b1;
                    state     <= S_IDLE;
                end

                S_QUERY_TX: begin
                    build_response(16'b0, byte_count);
                    tx_send <= 1'b1;
                    state   <= S_TX_WAIT;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
