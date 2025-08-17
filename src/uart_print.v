`timescale 1ns / 1ps
module uart_print #(
    parameter ADDR_WIDTH = 6,   // max message size 2^ADDR_WIDTH bytes
    parameter MSG_LEN_WIDTH = 7 // to hold length up to max 2^ADDR_WIDTH
)(
    input wire clk,
    input wire start,
    input wire [ADDR_WIDTH-1:0] msg_len,
    output wire ready,
    output wire uart_tx,

    // BRAM read interface
    input wire [ADDR_WIDTH-1:0] bram_raddr,
    input wire [7:0] bram_rdata
);

    localparam IDLE            = 3'd0,
               SEND_CHAR       = 3'd1,
               WAIT_READY_LOW  = 3'd2,
               WAIT_READY_HIGH = 3'd3;

    reg [2:0] state = IDLE;
    reg [ADDR_WIDTH-1:0] idx = 0;

    reg send = 0;
    reg [7:0] tx_byte = 8'd0;
    wire uart_ready;

    always @(posedge clk) begin
        send <= 0;
        case(state)
            IDLE: begin
                idx <= 0;
                if (start) begin
                    tx_byte <= bram_rdata;
                    send <= 1;
                    state <= WAIT_READY_LOW;
                end
            end

            WAIT_READY_LOW: begin
                if (!uart_ready)
                    state <= WAIT_READY_HIGH;
            end

            WAIT_READY_HIGH: begin
                if (uart_ready) begin
                    if (idx + 1 == msg_len) begin
                        state <= IDLE;
                    end else begin
                        idx <= idx + 1;
                        tx_byte <= bram_rdata;  // bram_rdata must be updated by top
                        send <= 1;
                        state <= WAIT_READY_LOW;
                    end
                end
            end

            default: state <= IDLE;
        endcase
    end

    assign ready = (state == IDLE);
    assign uart_tx = uart_tx_wire;

    // Instantiate UART_TX_CTRL module
    UART_TX_CTRL uart_tx_inst (
        .SEND(send),
        .DATA(tx_byte),
        .CLK(clk),
        .READY(uart_ready),
        .UART_TX(uart_tx_wire)
    );

endmodule
