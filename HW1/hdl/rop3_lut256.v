/*
* Module      : rop3_lut256
* Description : Implement this module using the look-up table (LUT).
*               This module should support all the possible modes of ROP3.
* Notes       : Please remember to make the bit-length of {Bitmap, Result} parameterizable.
*/

module rop3_lut256
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

// fsm
wire [1:0] state;
wire valid_ctl;

reg [7:0] M;
reg [N-1:0] P, S, D;
reg [N-1:0] nx_P, nx_S, nx_D;
reg [N-1:0] nx_Result;

reg [N-1:0] temp1, temp2, temp3, temp4, temp5, temp6, temp7;

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
always@* begin
	temp1 = (M[0])?(~((D|(P|S)))):0;
	temp2 = temp1 | ((M[1])?(D&(~(P|S))):0);
	temp3 = temp2 | ((M[2])?(S&(~(D|P))):0);
	temp4 = temp3 | ((M[3])?(S&(D&(~P))):0);
	temp5 = temp4 | ((M[4])?(P&(~(D|S))):0);
	temp6 = temp5 | ((M[5])?(D&(P&(~S))):0);
	temp7 = temp6 | ((M[6])?(P&(S&(~D))):0);
	nx_Result = temp7 | ((M[7])?(D&(P&S)):0);
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
