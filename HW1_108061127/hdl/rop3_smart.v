/*
* Module      : rop3_smart
* Description : Implement this module using the formulation mentioned in the assignment handout.
*               This module should support all the possible modes of ROP3.
* Notes       : Please remember to make the bit-length of {Bitmap, Result} parameterizable.
*/

module rop3_smart
#(
    parameter N = 8
)
(
    input clk,
	  input srst_n,
    input [N-1:0] Bitmap,
    input [7:0] Mode,
    output reg [N-1:0] Result,
	output reg valid
);

localparam IDLE = 2'd0, LOAD_P = 2'd1, LOAD_S = 2'd2, LOAD_D = 2'd3;
integer i;

// fsm
wire [1:0] state;
wire valid_ctl;

reg [7:0] M;
reg [N-1:0] P, S, D;
reg [N-1:0] nx_P, nx_S, nx_D;
reg [N-1:0] nx_Result;
reg [7:0] temp1, temp2;

//MUX
always@*
  case(state)
    IDLE: begin
      nx_P = P;
      nx_S = S;
      nx_D = D;
    end
    LOAD_P: begin
      nx_P = Bitmap;
      nx_S = S;
      nx_D = D;
    end
    LOAD_S: begin
      nx_P = P;
      nx_S = Bitmap;
      nx_D = D;
    end
    LOAD_D: begin
      nx_P = P;
      nx_S = S;
      nx_D = Bitmap;
    end
    default: begin
      nx_P = P;
      nx_S = S;
      nx_D = Bitmap;
    end
  endcase

//Functions
always@*
  for(i = 0; i < N; i = i + 1) begin
    temp1 = 8'h1 << {P[i], S[i], D[i]};
    temp2 = temp1 & M;
    nx_Result[i] = | temp2;
  end

//DFF
always@(posedge clk)
  begin
    if(state === IDLE) begin
      P <= nx_P;
      S <= nx_S;
      D <= nx_D;
      M <= 8'b0;
    end
    else begin
      P <= nx_P;
      S <= nx_S;
      D <= nx_D;
      M <= Mode;
    end
  end

always@(posedge clk)
  begin
    Result <= nx_Result;
    valid <= valid_ctl;
  end

  fsm fsm_U0(
  	.clk(clk),
  	.srst_n(srst_n),
  	.state(state),
  	.valid_ctl(valid_ctl)
  );

endmodule
