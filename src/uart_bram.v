`timescale 1ns / 1ps
module uart_bram #(
    parameter ADDR_WIDTH = 6,      // 64 bytes by default
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    // Write port
    input wire we,
    input wire [ADDR_WIDTH-1:0] waddr,
    input wire [DATA_WIDTH-1:0] wdata,
    // Read port
    input wire [ADDR_WIDTH-1:0] raddr,
    output reg [DATA_WIDTH-1:0] rdata
);

    // BRAM memory array
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end

endmodule
