/*
* Module      : fsm (finite state machine)
* Description : Control when to load P, S, D through the Bitmap input port and when to set valid to high.
* Note        : This module has been done by TA. 
*               *** Do not modify this module. ***
*/

module fsm(
    input clk,
    input srst_n,
    output reg [1:0] state,
    output reg valid_ctl
);

localparam IDLE = 2'd0, LOAD_P = 2'd1, LOAD_S = 2'd2, LOAD_D = 2'd3;
reg [1:0] n_state;
reg n_valid_ctl;

always@* begin
    // state
    case(state)
        IDLE: n_state = LOAD_P;
        LOAD_P: n_state = LOAD_S;
        LOAD_S: n_state = LOAD_D;
        LOAD_D: n_state = LOAD_P;
        default: n_state = IDLE;
    endcase

    // valid control
    n_valid_ctl = (state == LOAD_D)? 1 : 0;
end

always@(posedge clk) begin
    if(~srst_n) begin
        state <= IDLE;
        valid_ctl <= 0;
    end
    else begin
        state <= n_state;
        valid_ctl <= n_valid_ctl;
    end
end

endmodule