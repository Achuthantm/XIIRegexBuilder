`timescale 1ns / 1ps

// NFA for regex index 5
module nfa_5 (
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
    reg [11:0] state_reg;
    wire [11:0] next_state;

    assign next_state[0] = 1'b0;
    assign next_state[1] = (state_reg[0] && (char_in == 8'd97));
    assign next_state[2] = (state_reg[1] && (char_in == 8'd112));
    assign next_state[3] = (state_reg[2] && (char_in == 8'd112));
    assign next_state[4] = (state_reg[3] && (char_in == 8'd108));
    assign next_state[5] = (state_reg[4] && (char_in == 8'd101));
    assign next_state[6] = (state_reg[0] && (char_in == 8'd111));
    assign next_state[7] = (state_reg[6] && (char_in == 8'd114));
    assign next_state[8] = (state_reg[7] && (char_in == 8'd97));
    assign next_state[9] = (state_reg[8] && (char_in == 8'd110));
    assign next_state[10] = (state_reg[9] && (char_in == 8'd103));
    assign next_state[11] = (state_reg[10] && (char_in == 8'd101));

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
                match <= (|{state_reg[5], state_reg[11]});
            end else begin
                match <= 1'b0;
            end
        end
    end

    // Active logic: high if any state other than state 0 is active
    assign active = |state_reg[11:1];

endmodule
