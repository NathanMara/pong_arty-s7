`timescale 1ns / 1ps

module vga_controller (
    input wire clk,             // 100 MHz input clock
    output reg hsync,          // horizontal sync output
    output reg vsync,          // vertical sync output
    output wire video_on,      // high when visible area is active
    output wire [9:0] x,       // current x position (0-639)
    output wire [8:0] y        // current y position (0-479)
    );

    // 25 MHz pixel clock (from 100 MHz)
    reg [1:0] clk_div = 0;
    wire pix_clk = clk_div == 0;

    always @(posedge clk)
        clk_div <= clk_div + 1;

    // VGA 640x480 @ 60Hz timing constants
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    // Horizontal and vertical counters
    always @(posedge clk) begin
        if (pix_clk) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // Generate sync pulses (active low)
    always @(posedge clk) begin
        if (pix_clk) begin
            hsync <= ~(h_count >= H_VISIBLE + H_FRONT &&
                       h_count <  H_VISIBLE + H_FRONT + H_SYNC);

            vsync <= ~(v_count >= V_VISIBLE + V_FRONT &&
                       v_count <  V_VISIBLE + V_FRONT + V_SYNC);
        end
    end

    // Only show video inside visible area
    assign video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    assign x = h_count;
    assign y = v_count;

endmodule
