`timescale 1ns / 1ps

module top_level (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    input  wire        BTNC,          // start
    input  wire        BTNU,          // char_valid
    input  wire        BTND,          // end_of_str
    input  wire        UART_TXD_IN,
    output wire        UART_RXD_OUT,
    output wire [15:0] LED,
    output wire [ 7:0] SEG,
    output wire [ 7:0] AN
);

  // --- Input Synchronization and Debouncing ---
  reg [1:0] rst_sync;
  always @(posedge CLK100MHZ) rst_sync <= {rst_sync[0], !CPU_RESETN};
  wire rst = rst_sync[1];

  reg [15:0] btnc_sync, btnu_sync, btnd_sync;
  always @(posedge CLK100MHZ) begin
    btnc_sync <= {btnc_sync[14:0], BTNC};
    btnu_sync <= {btnu_sync[14:0], BTNU};
    btnd_sync <= {btnd_sync[14:0], BTND};
  end
  wire btnc_debounced = &btnc_sync;
  wire btnu_debounced = &btnu_sync;
  wire btnd_debounced = &btnd_sync;

  reg btnc_prev, btnu_prev, btnd_prev;
  always @(posedge CLK100MHZ) begin
    btnc_prev <= btnc_debounced;
    btnu_prev <= btnu_debounced;
    btnd_prev <= btnd_debounced;
  end
  wire       btnc_pulse = btnc_debounced && !btnc_prev;
  wire       btnu_pulse = btnu_debounced && !btnu_prev;
  wire       btnd_pulse = btnd_debounced && !btnd_prev;

  // UART Instance with FIFO
  wire [7:0] rx_fifo_data;
  wire       rx_fifo_valid;
  wire       ready_out;
  wire       rx_rd_en = (rx_fifo_valid && (ready_out || prog_state != 0));

  uart_rx #(
      .CLK_FREQ(100000000),
      .BAUD_RATE(115200),
      .FIFO_DEPTH(32)  // Increased FIFO
  ) rx_inst (
      .clk(CLK100MHZ),
      .rst(rst),
      .rx(UART_TXD_IN),
      .data(rx_fifo_data),
      .valid(rx_fifo_valid),
      .rd_en(rx_rd_en)
  );

  reg  [7:0] tx_data_reg;
  reg        tx_send_reg;
  wire       tx_ready;
  uart_tx tx_inst (
      .clk(CLK100MHZ),
      .rst(rst),
      .data(tx_data_reg),
      .send(tx_send_reg),
      .tx(UART_RXD_OUT),
      .ready(tx_ready)
  );

  // Protocol Logic
  wire is_stx = (rx_rd_en && rx_fifo_data == 8'h02 && prog_state == 0);
  wire start_pulse = (btnc_pulse) || (rx_rd_en && rx_fifo_data == 8'h01 && prog_state == 0);
  wire end_of_str_pulse = (btnd_pulse) || (rx_rd_en && (rx_fifo_data == 8'h0D || rx_fifo_data == 8'h0A) && prog_state == 0);
  wire is_printable = (rx_fifo_data >= 8'h20 && rx_fifo_data <= 8'h7E);
  wire char_valid_pulse = (btnu_pulse) || (rx_rd_en && is_printable && prog_state == 0);

  // --- UART Programming Logic ---
  reg [2:0] prog_state = 0;
  reg [7:0] prog_addr_reg;
  reg [31:0] prog_data_reg;
  reg prog_en_reg;
  reg [26:0] prog_watchdog = 0;  // ~1.3s timeout at 100MHz

  always @(posedge CLK100MHZ) begin
    if (rst || prog_watchdog[26]) begin
      prog_state <= 0;
      prog_en_reg <= 0;
      prog_watchdog <= 0;
    end else begin
      prog_en_reg <= 0;
      if (prog_state != 0) prog_watchdog <= prog_watchdog + 1;
      else prog_watchdog <= 0;

      case (prog_state)
        0: if (is_stx) prog_state <= 1;
        1:
        if (rx_fifo_valid) begin
          prog_addr_reg <= rx_fifo_data;
          prog_state <= 2;
          prog_watchdog <= 0;
        end
        2:
        if (rx_fifo_valid) begin
          prog_data_reg[31:24] <= rx_fifo_data;
          prog_state <= 3;
          prog_watchdog <= 0;
        end
        3:
        if (rx_fifo_valid) begin
          prog_data_reg[23:16] <= rx_fifo_data;
          prog_state <= 4;
          prog_watchdog <= 0;
        end
        4:
        if (rx_fifo_valid) begin
          prog_data_reg[15:8] <= rx_fifo_data;
          prog_state <= 5;
          prog_watchdog <= 0;
        end
        5:
        if (rx_fifo_valid) begin
          prog_data_reg[7:0] <= rx_fifo_data;
          prog_en_reg <= 1;
          prog_state <= 0;
        end
        default: prog_state <= 0;
      endcase
    end
  end

  // --- UART Activity Monitor ---
  reg [23:0] rx_activity_cnt;
  reg [23:0] tx_activity_cnt;
  always @(posedge CLK100MHZ) begin
    if (rx_rd_en || (prog_state != 0 && rx_fifo_valid)) rx_activity_cnt <= 24'hFFFFFF;
    else if (rx_activity_cnt > 0) rx_activity_cnt <= rx_activity_cnt - 1;

    if (tx_send_reg) tx_activity_cnt <= 24'hFFFFFF;
    else if (tx_activity_cnt > 0) tx_activity_cnt <= tx_activity_cnt - 1;
  end

  wire [15:0] match_bus;
  regex_cpu #(
      .NUM_REGEX(16)
  ) cpu_inst (
      .clk(CLK100MHZ),
      .rst(rst),
      .start(start_pulse),
      .end_of_str(end_of_str_pulse),
      .char_in(rx_fifo_valid ? rx_fifo_data : SW[7:0]),
      .char_valid(char_valid_pulse),
      .prog_en(prog_en_reg),
      .prog_addr(prog_addr_reg),
      .prog_data(prog_data_reg),
      .ready(ready_out),
      .match_bus(match_bus)
  );

  assign LED[11:0] = match_bus[11:0];
  assign LED[13]   = (tx_activity_cnt > 0);  // TX Flash
  assign LED[14]   = (rx_activity_cnt > 0);  // RX Flash
  assign LED[15]   = ready_out;

  // --- UART Result Transmission ---
  reg [ 2:0] tx_state = 0;
  reg [19:0] tx_delay_cnt = 0;
  always @(posedge CLK100MHZ) begin
    if (rst) begin
      tx_state <= 0;
      tx_send_reg <= 0;
      tx_delay_cnt <= 0;
    end else begin
      tx_send_reg <= 0;
      case (tx_state)
        0: if (end_of_str_pulse) tx_state <= 1;
        1: if (ready_out) tx_state <= 2;  // Wait for CPU to finish STATE_END_OF_STR
        2:
        if (tx_ready) begin
          tx_data_reg <= match_bus[15:8];
          tx_send_reg <= 1;
          tx_state <= 3;
        end
        3: if (!tx_ready) tx_state <= 4;
        4:
        if (tx_ready) begin
          if (tx_delay_cnt == 20'd100000) begin
            tx_data_reg <= match_bus[7:0];
            tx_send_reg <= 1;
            tx_state <= 0;
            tx_delay_cnt <= 0;
          end else begin
            tx_delay_cnt <= tx_delay_cnt + 1;
          end
        end
        default: tx_state <= 0;
      endcase
    end
  end

  // --- 7-Segment Display (Unchanged) ---
  function [6:0] sseg_dec;
    input [3:0] val;
    begin
      case (val)
        4'h0: sseg_dec = 7'b1000000;
        4'h1: sseg_dec = 7'b1111001;
        4'h2: sseg_dec = 7'b0100100;
        4'h3: sseg_dec = 7'b0110000;
        4'h4: sseg_dec = 7'b0011001;
        4'h5: sseg_dec = 7'b0010010;
        4'h6: sseg_dec = 7'b0000010;
        4'h7: sseg_dec = 7'b1111000;
        4'h8: sseg_dec = 7'b0000000;
        4'h9: sseg_dec = 7'b0010000;
        4'hA: sseg_dec = 7'b0001000;
        4'hB: sseg_dec = 7'b0000011;
        4'hC: sseg_dec = 7'b1000110;
        4'hD: sseg_dec = 7'b0100001;
        4'hE: sseg_dec = 7'b0000110;
        4'hF: sseg_dec = 7'b0001110;
        default: sseg_dec = 7'b1111111;
      endcase
    end
  endfunction
  reg [19:0] refresh_counter = 0;
  always @(posedge CLK100MHZ) refresh_counter <= refresh_counter + 1;
  assign AN = (refresh_counter[18]) ? 8'b11111110 : 8'b11111101;
  assign SEG[6:0] = (refresh_counter[18]) ? sseg_dec(SW[3:0]) : sseg_dec(SW[7:4]);
  assign SEG[7] = 1'b1;
endmodule
