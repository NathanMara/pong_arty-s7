`timescale 1ns / 1ps

module pong_uart #(
    parameter MSG_LEN = 17,
    parameter ADDR_WIDTH = 6
)(
    input wire clk,
    input wire [2:0] p1_score,
    input wire [2:0] p2_score,
    input wire p1_scored,
    input wire p2_scored,
    output wire uart_tx
);

    // UART
    wire uart_ready;
    reg start_uart = 0;

    // BRAM
    reg we = 0;
    reg [ADDR_WIDTH-1:0] waddr = 0;
    reg [ADDR_WIDTH-1:0] raddr = 0;
    wire [7:0] rdata;
    wire [ADDR_WIDTH-1:0] uart_idx;

    // UART BRAM
    uart_bram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(8)
    ) msg_bram (
        .clk(clk),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr(raddr),
        .rdata(rdata)
    );

    // UART Printer
    uart_print #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .MSG_LEN_WIDTH($clog2(MSG_LEN))
    ) printer (
        .clk(clk),
        .start(start_uart),
        .msg_len(MSG_LEN),
        .ready(uart_ready),
        .uart_tx(uart_tx),
        .bram_raddr(uart_idx),
        .bram_rdata(rdata)
    );

    // FSM state encoding
    localparam STATE_IDLE   = 0;
    localparam STATE_LOAD   = 1;
    localparam STATE_START  = 2;
    localparam STATE_WAIT   = 3;
    localparam STATE_RESET  = 4;

    reg [2:0] state = STATE_START;
    reg [4:0] write_idx = 0;
    reg [15:0] reset_counter = 0;
    reg selected_player = 0; // 0 = P1, 1 = P2

    // Score pulse detection
    reg p1_prev = 0, p2_prev = 0;
    wire p1_rise = p1_scored & ~p1_prev;
    wire p2_rise = p2_scored & ~p2_prev;

    reg [7:0] wdata;

    always @(posedge clk) begin
        // Rising edge detection
        p1_prev <= p1_scored;
        p2_prev <= p2_scored;

        case (state)
            STATE_IDLE: begin
                we <= 0;
                start_uart <= 0;
                write_idx <= 0;
                waddr <= 0;
                if (uart_ready && (p1_rise || p2_rise)) begin
                    selected_player <= p2_rise;
                    state <= STATE_LOAD;
                end
            end

            STATE_LOAD: begin
                we <= 1;

                case (write_idx)
                    0:  wdata <= "P";
                    1:  wdata <= "l";
                    2:  wdata <= "a";
                    3:  wdata <= "y";
                    4:  wdata <= "e";
                    5:  wdata <= "r";
                    6:  wdata <= " ";
                    7:  wdata <= selected_player ? "2" : "1";
                    8:  wdata <= "+";
                    9:  wdata <= " ";
                    10: wdata <= "(";
                    11: wdata <= selected_player ? (8'd48 + p2_score) : (8'd48 + p1_score); // ASCII '0' + score
                    12: wdata <= ")";
                    13: wdata <= 8'h0D;
                    14: wdata <= 8'h0A;
                    15: wdata <= 8'h0A;
                endcase

                if (write_idx == MSG_LEN - 1)
                    state <= STATE_START;
                else
                    write_idx <= write_idx + 1;

                waddr <= waddr + 1;
            end

            STATE_START: begin
                we <= 0;
                start_uart <= 1;
                state <= STATE_WAIT;
            end

            STATE_WAIT: begin
                start_uart <= 0;
                if (uart_ready) begin
                    reset_counter <= 0;
                    state <= STATE_RESET;
                end
            end

            STATE_RESET: begin
                reset_counter <= reset_counter + 1;
                if (reset_counter >= 16'd50000) begin
                    state <= STATE_IDLE;
                end
            end
        endcase

        raddr <= printer.idx;
    end
endmodule
