`timescale 1ns / 1ps

module top (
    input wire clk,
    input wire [3:0] btn,
    output wire [3:0] red,
    output wire [3:0] green,
    output wire [3:0] blue,
    output wire hsync,
    output wire vsync,
    output wire uart_tx,
    output wire [3:0] led
);

    wire [9:0] x;
    wire [8:0] y;
    wire video_on;
    wire [2:0] p1_score, p2_score;
    wire p1_scored, p2_scored;

    // VGA Timing
    vga_controller vga (
        .clk(clk),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .x(x),
        .y(y)
    );

    // Pong Game Logic
    pong_game game_inst (
        .clk(clk),
        .x(x),
        .y(y),
        .video_on(video_on),
        .btn(btn),
        .red(red),
        .green(green),
        .blue(blue),
        .p1_scored(p1_scored),
        .p2_scored(p2_scored),
        .p1_score_out(p1_score),
        .p2_score_out(p2_score)
    );
    
    pong_uart uart_score_printer (
        .clk(clk),
        .p1_score(p1_score),
        .p2_score(p2_score),
        .p1_scored(p1_scored),
        .p2_scored(p2_scored),
        .uart_tx(uart_tx)
    );

endmodule