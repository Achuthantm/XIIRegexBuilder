`timescale 1ns / 1ps

// NFA for regex index 11
module nfa_11 (
    input  wire       clk,
    input  wire       en,
    input  wire       rst,
    input  wire       start,
    input  wire       end_of_str,
    input  wire [7:0] char_in,
    output reg        match,
    output wire       active
);

    // One-hot state register
    reg [4:0] state_reg;
    wire [4:0] next_state;

    assign next_state[0] = 1'b0;
    assign next_state[1] = (state_reg[0] && (char_in >= 8'd32) && (char_in <= 8'd126)) | (state_reg[1] && (char_in >= 8'd32) && (char_in <= 8'd126));
    assign next_state[2] = (state_reg[0] && (char_in == 8'd101)) | (state_reg[1] && (char_in == 8'd101));
    assign next_state[3] = (state_reg[2] && (char_in == 8'd110));
    assign next_state[4] = (state_reg[3] && (char_in == 8'd100));

    always @(posedge clk) begin
        if (rst || start) begin
            // Reset to start state (one-hot)
            state_reg <= 1 << 0;
        end else if (en) begin
            state_reg <= next_state;
        end
    end

    // Match logic: asserted on cycle following end_of_str
    always @(posedge clk) begin
        if (rst || start) begin
            match <= 1'b0;
        end else if (en) begin
            if (end_of_str) begin
                match <= state_reg[4];
            end else begin
                match <= 1'b0;
            end
        end
    end

    // Active logic: high if any state other than state 0 is active
    assign active = |state_reg[4:1];

endmodule
