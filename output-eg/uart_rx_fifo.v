`timescale 1ns / 1ps


module uart_rx_fifo #(
    parameter DEPTH_LOG2 = 4        // depth = 2^DEPTH_LOG2 = 16
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] wr_data,
    input  wire       wr_en,
    output wire       full,
    output wire [7:0] rd_data,
    input  wire       rd_en,
    output wire       empty
);
    localparam DEPTH = 1 << DEPTH_LOG2;

    reg [7:0] mem [0:DEPTH-1];
    reg [DEPTH_LOG2-1:0] wr_ptr = {DEPTH_LOG2{1'b0}};
    reg [DEPTH_LOG2-1:0] rd_ptr = {DEPTH_LOG2{1'b0}};
    reg [DEPTH_LOG2  :0] count  = {(DEPTH_LOG2+1){1'b0}};

    assign full    = (count == DEPTH[DEPTH_LOG2:0]);
    assign empty   = (count == {(DEPTH_LOG2+1){1'b0}});
    assign rd_data = mem[rd_ptr];

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {DEPTH_LOG2{1'b0}};
            rd_ptr <= {DEPTH_LOG2{1'b0}};
            count  <= {(DEPTH_LOG2+1){1'b0}};
        end else begin
            if (wr_en && !full && rd_en && !empty) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1;
                rd_ptr      <= rd_ptr + 1;
            end else if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1;
                count       <= count + 1;
            end else if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
                count  <= count - 1;
            end
        end
    end
endmodule
