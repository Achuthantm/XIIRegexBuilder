`timescale 1ns / 1ps

module regex_cpu #(
    parameter NUM_REGEX = 16
) (
    input wire       clk,
    input wire       rst,
    input wire       start,
    input wire       end_of_str,
    input wire [7:0] char_in,
    input wire       char_valid,

    input wire        prog_en,
    input wire [ 7:0] prog_addr,
    input wire [31:0] prog_data,

    output wire                 ready,
    output reg  [NUM_REGEX-1:0] match_bus
);

  // --- Instruction Memory (BRAM Inferred) ---
  reg [31:0] imem[0:255];
  initial $readmemh("processor/build/imem.hex", imem);

  always @(posedge clk) begin
    if (prog_en) imem[prog_addr] <= prog_data;
  end

  // --- State Machine ---
  localparam STATE_IDLE = 3'd0;
  localparam STATE_START_INIT = 3'd1;
  localparam STATE_CHAR_MATCH = 3'd2;
  localparam STATE_EPSILON_RECURSE = 3'd3;
  localparam STATE_END_OF_STR = 3'd4;

  reg [  2:0] state = STATE_IDLE;
  reg [255:0] active_candidates;
  reg [  5:0] recurse_count;
  reg [  7:0] pc_cnt;
  reg [255:0] next_set_buffer;
  reg [  7:0] char_reg;
  reg         recurse_changed;

  assign ready = (state == STATE_IDLE);

  // Single-port instruction fetch
  wire [31:0] current_instr = imem[pc_cnt];
  wire [ 7:0] p_char = current_instr[31:24];
  wire [ 7:0] p_next1 = current_instr[23:16];
  wire [ 7:0] p_next2 = current_instr[15:8];
  wire [ 3:0] p_mid = current_instr[7:4];
  wire        p_term = current_instr[3];
  wire        p_any = current_instr[0];

  always @(posedge clk) begin
    if (rst) begin
      state <= STATE_IDLE;
      active_candidates <= 0;
      match_bus <= 0;
      recurse_count <= 0;
      char_reg <= 0;
      pc_cnt <= 0;
      next_set_buffer <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (start) begin
            state <= STATE_START_INIT;
            match_bus <= 0;
          end else if (char_valid) begin
            char_reg <= char_in;
            pc_cnt <= 0;
            next_set_buffer <= 0;
            state <= STATE_CHAR_MATCH;
          end else if (end_of_str) begin
            pc_cnt <= 0;
            state  <= STATE_END_OF_STR;
          end
        end

        STATE_START_INIT: begin
          active_candidates <= 256'd1;  // Start at Address 0 (the split chain)
          recurse_count <= 0;
          pc_cnt <= 0;
          recurse_changed <= 0;
          state <= STATE_EPSILON_RECURSE;
        end

        STATE_CHAR_MATCH: begin
          if (active_candidates[pc_cnt]) begin
            if (p_any || (p_char != 0 && p_char == char_reg)) begin
              if (p_next1 != 0) next_set_buffer[p_next1] <= 1'b1;
              if (p_next2 != 0) next_set_buffer[p_next2] <= 1'b1;
            end
          end

          if (pc_cnt == 8'd255) begin
            active_candidates <= next_set_buffer;
            recurse_count <= 0;
            pc_cnt <= 0;
            recurse_changed <= 1; // Force at least one pass of epsilon recurse
            state <= STATE_EPSILON_RECURSE;
          end else begin
            pc_cnt <= pc_cnt + 1;
          end
        end

        STATE_EPSILON_RECURSE: begin
          // One pass over all nodes to expand epsilon transitions
          if (active_candidates[pc_cnt] && p_char == 0 && !p_any && !p_term) begin
            active_candidates[pc_cnt] <= 1'b0;  // Node consumed
            if (p_next1 != 0) active_candidates[p_next1] <= 1'b1;
            if (p_next2 != 0) active_candidates[p_next2] <= 1'b1;
            recurse_changed <= 1;
          end

          if (pc_cnt == 8'd255) begin
            if (recurse_count == 6'd63 || !recurse_changed) begin
              state <= STATE_IDLE;
            end else begin
              recurse_count <= recurse_count + 1;
              pc_cnt <= 0;
              recurse_changed <= 0;
            end
          end else begin
            pc_cnt <= pc_cnt + 1;
          end
        end

        STATE_END_OF_STR: begin
          if (active_candidates[pc_cnt] && p_term) begin
            match_bus[p_mid] <= 1'b1;
          end

          if (pc_cnt == 8'd255) begin
            state <= STATE_IDLE;
          end else begin
            pc_cnt <= pc_cnt + 1;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
