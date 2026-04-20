`timescale 1ns / 1ps

// NFA for regex index 0
module nfa_0 (
    input  wire       clk,
    input  wire       en,
    input  wire       rst,
    input  wire       start,
    input  wire       end_of_str,
    input  wire [7:0] char_in,
    output wire       match,
    output wire       active
);

    // One-hot state register
    reg [5:0] state_reg;
    wire [5:0] next_state;

    assign next_state[0] = 1'b1;
    assign next_state[1] = (state_reg[0] && (char_in == 8'd46)) | (state_reg[0] && (char_in >= 8'd48) && (char_in <= 8'd57)) | (state_reg[0] && (char_in >= 8'd65) && (char_in <= 8'd90)) | (state_reg[0] && (char_in >= 8'd97) && (char_in <= 8'd122)) | (state_reg[1] && (char_in == 8'd46)) | (state_reg[1] && (char_in >= 8'd48) && (char_in <= 8'd57)) | (state_reg[1] && (char_in >= 8'd65) && (char_in <= 8'd90)) | (state_reg[1] && (char_in >= 8'd97) && (char_in <= 8'd122));
    assign next_state[2] = (state_reg[1] && (char_in == 8'd64));
    assign next_state[3] = (state_reg[2] && (char_in == 8'd46)) | (state_reg[2] && (char_in >= 8'd48) && (char_in <= 8'd57)) | (state_reg[2] && (char_in >= 8'd65) && (char_in <= 8'd90)) | (state_reg[2] && (char_in >= 8'd97) && (char_in <= 8'd122)) | (state_reg[3] && (char_in == 8'd46)) | (state_reg[3] && (char_in >= 8'd48) && (char_in <= 8'd57)) | (state_reg[3] && (char_in >= 8'd65) && (char_in <= 8'd90)) | (state_reg[3] && (char_in >= 8'd97) && (char_in <= 8'd122));
    assign next_state[4] = (state_reg[3] && (char_in == 8'd46));
    assign next_state[5] = (state_reg[4] && (char_in >= 8'd65) && (char_in <= 8'd90)) | (state_reg[4] && (char_in >= 8'd97) && (char_in <= 8'd122)) | (state_reg[5] && (char_in >= 8'd65) && (char_in <= 8'd90)) | (state_reg[5] && (char_in >= 8'd97) && (char_in <= 8'd122));

    always @(posedge clk) begin
        if (rst || start) begin
            // Reset to start state (one-hot)
            state_reg <= 1 << 0;
        end else if (en) begin
            state_reg <= next_state;
        end
    end

    // Match logic: asserted immediately on accept state (combinational)
    assign match = state_reg[5];

    // Active logic: high if any state other than state 0 is active
    assign active = |state_reg[5:1];

endmodule
