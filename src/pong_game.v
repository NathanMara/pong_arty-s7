`timescale 1ns / 1ps

module pong_game (
    input wire clk,
    input wire [9:0] x,
    input wire [8:0] y,
    input wire video_on,
    input wire [3:0] btn,  // btn[0] = player 1 up, btn[1] = player 1 down
    output wire [3:0] red,
    output wire [3:0] green,
    output wire [3:0] blue,
    output wire [2:0] p1_score_out,
    output wire [2:0] p2_score_out,
    output reg p1_scored,
    output reg p2_scored
);

    localparam SCREEN_WIDTH  = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam PADDLE_WIDTH  = 10;
    localparam PADDLE_HEIGHT = 60;
    localparam BALL_SIZE     = 8;

    localparam PADDLE1_X = 30;
    localparam PADDLE2_X = SCREEN_WIDTH - 30 - PADDLE_WIDTH;

    reg [8:0] paddle1_y = 210;
    reg [8:0] paddle2_y = 210;

    reg [9:0] ball_x = 320;
    reg [8:0] ball_y = 240;
    reg ball_dx = 0; // 1=right, 0=left
    reg ball_dy = 0; // 1=down,  0=up
    reg [9:0] next_ball_x;
    reg [8:0] next_ball_y;
    
    reg [2:0] p1_score = 0;
    reg [2:0] p2_score = 0;
    
    reg  paddle_reset_request = 1'b1;

    // Ball/score FSM states
    localparam IDLE     = 2'b00;
    localparam PLAY     = 2'b01;
    localparam SCORE_P1 = 2'b10;
    localparam SCORE_P2 = 2'b11;
    reg [1:0] state = IDLE;

    // Paddle FSM states
    localparam PADDLE_RESTART = 1'b0;
    localparam PADDLE_MOVE    = 1'b1;
    reg paddle_state = PADDLE_RESTART;

    // Clock divider for game tick
    reg [19:0] div_cnt = 0;
    wire tick = (div_cnt == 0);
    always @(posedge clk) div_cnt <= div_cnt + 1;

    // --- Paddle FSM ---
    always @(posedge clk) begin
        if (tick) begin
            case (paddle_state)
                PADDLE_RESTART: begin
                    paddle1_y <= 210;
                    paddle2_y <= 210;
                    paddle_state <= PADDLE_MOVE;
                end

                PADDLE_MOVE: begin
                    if (paddle_reset_request)
                        paddle_state <= PADDLE_RESTART;
                    else begin
                        // Player 1 up/down
                        if (btn[0] && paddle1_y >= 4)
                            paddle1_y <= paddle1_y - 4;
                        else if (btn[1] && paddle1_y <= SCREEN_HEIGHT - PADDLE_HEIGHT - 4)
                            paddle1_y <= paddle1_y + 4;

                        // Player 2 up/down
                        if (btn[2] && paddle2_y >= 4)
                            paddle2_y <= paddle2_y - 4;
                        else if (btn[3] && paddle2_y <= SCREEN_HEIGHT - PADDLE_HEIGHT - 4)
                            paddle2_y <= paddle2_y + 4;
                    end
                end
            endcase
        end
    end

    // --- Ball movement and scoring FSM ---
    always @(posedge clk) begin
        p1_scored <= 0;
        p2_scored <= 0;

        if (tick) begin
            case (state)
                IDLE: begin
                    ball_x <= 320;
                    ball_y <= 240;
                    ball_dx <= 0;
                    ball_dy <= 0;
                    paddle_reset_request <= 1'b0;
                    state <= PLAY;
                end

                PLAY: begin
                    next_ball_x = ball_dx ? ball_x + 2 : ball_x - 2;
                    next_ball_y = ball_dy ? ball_y + 2 : ball_y - 2;

                    // Bounce off top
                    if (next_ball_y <= 0) begin
                        ball_dy <= 1;
                        ball_y <= 0;
                    end
                    // Bounce off bottom
                    else if (next_ball_y + BALL_SIZE >= SCREEN_HEIGHT) begin
                        ball_dy <= 0;
                        ball_y <= SCREEN_HEIGHT - BALL_SIZE;
                    end
                    else begin
                        ball_y <= next_ball_y;
                    end

                    // Bounce off paddle 1 (left)
                    if (ball_dx == 0 &&
                        (next_ball_x + BALL_SIZE) >= PADDLE1_X &&
                        next_ball_x <= (PADDLE1_X + PADDLE_WIDTH) &&
                        (next_ball_y + BALL_SIZE) >= paddle1_y &&
                        next_ball_y <= (paddle1_y + PADDLE_HEIGHT)) begin
                        ball_dx <= 1;
                        ball_x <= PADDLE1_X + PADDLE_WIDTH + 1;
                    end
                    // Bounce off paddle 2 (right)
                    else if (ball_dx == 1 &&
                             next_ball_x <= (PADDLE2_X + PADDLE_WIDTH) &&
                             (next_ball_x + BALL_SIZE) >= PADDLE2_X &&
                             (next_ball_y + BALL_SIZE) >= paddle2_y &&
                             next_ball_y <= (paddle2_y + PADDLE_HEIGHT)) begin
                        ball_dx <= 0;
                        ball_x <= PADDLE2_X - BALL_SIZE - 1;
                    end
                    else begin
                        ball_x <= next_ball_x;
                    end

                    // Check if scored
                    if (ball_x <= 1)
                        state <= SCORE_P2;
                    else if (ball_x + BALL_SIZE >= SCREEN_WIDTH)
                        state <= SCORE_P1;
                end

                SCORE_P1: begin
                    p1_scored <= 1;
                    if (p1_score == 7) begin
                        p1_score <= 0;
                        p2_score <= 0;
                        paddle_reset_request <= 1'b1;
                        state <= IDLE;
                    end else begin
                        p1_score <= p1_score + 1;
                        ball_x <= 320;
                        ball_y <= 240;
                        ball_dx <= 0;
                        ball_dy <= 0;
                        state <= PLAY;
                    end
                end
                
                SCORE_P2: begin
                    p2_scored <= 1;
                    if (p2_score == 7) begin
                        p1_score <= 0;
                        p2_score <= 0;
                        paddle_reset_request <= 1'b1;
                        state <= IDLE;
                    end else begin
                        p2_score <= p2_score + 1;
                        ball_x <= 320;
                        ball_y <= 240;
                        ball_dx <= 1;
                        ball_dy <= 0;
                        state <= PLAY;
                    end
                end 

            endcase
        end
    end

    // Drawing logic
    wire draw_paddle1 = (x >= PADDLE1_X) &&
                        (x < PADDLE1_X + PADDLE_WIDTH) &&
                        (y >= paddle1_y) &&
                        (y < paddle1_y + PADDLE_HEIGHT);

    wire draw_paddle2 = (x >= PADDLE2_X) &&
                        (x < PADDLE2_X + PADDLE_WIDTH) &&
                        (y >= paddle2_y) &&
                        (y < paddle2_y + PADDLE_HEIGHT);

    wire draw_ball = (x >= ball_x) &&
                     (x < ball_x + BALL_SIZE) &&
                     (y >= ball_y) &&
                     (y < ball_y + BALL_SIZE);

    wire drawing = video_on && (draw_paddle1 || draw_paddle2 || draw_ball);

    assign red   = drawing ? (draw_ball ? 4'hF : 4'h0) : 4'h0;
    assign green = drawing ? ((draw_paddle1 || draw_paddle2) ? 4'hF : 4'h0) : 4'h0;
    assign blue  = 4'h0;
    assign p1_score_out = p1_score;
    assign p2_score_out = p2_score;

endmodule
