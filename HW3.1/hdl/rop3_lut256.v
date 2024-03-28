/*
* Module      : rop3_lut256
* Description : Implement this module using the look-up table (LUT).
*               This module should support all the possible modes of ROP3.
* Notes       : Please remember to make the bit-length of {Bitmap, Result} parameterizable.
*/

module rop3_lut256
#(
	parameter N = 32
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
  case(M)
		8'h0: nx_Result = 0|0|0|0|0|0|0|0;
		8'h1: nx_Result = (~((D|(P|S))))|0|0|0|0|0|0|0;
		8'h2: nx_Result = 0|(D&(~(P|S)))|0|0|0|0|0|0;
		8'h3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|0|0|0;
		8'h4: nx_Result = 0|0|(S&(~(D|P)))|0|0|0|0|0;
		8'h5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|0|0|0;
		8'h6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|0|0;
		8'h7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|0|0;
		8'h8: nx_Result = 0|0|0|(S&(D&(~P)))|0|0|0|0;
		8'h9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|0|0|0;
		8'ha: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|0|0;
		8'hb: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|0|0;
		8'hc: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|0;
		8'hd: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|0;
		8'he: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|0;
		8'hf: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|0;
		8'h10: nx_Result = 0|0|0|0|(P&(~(D|S)))|0|0|0;
		8'h11: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|0|0|0;
		8'h12: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|0|0;
		8'h13: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|0|0;
		8'h14: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|0;
		8'h15: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|0;
		8'h16: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|0;
		8'h17: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|0;
		8'h18: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h19: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h1a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h1b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h1c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h1d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h1e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h1f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|0;
		8'h20: nx_Result = 0|0|0|0|0|(D&(P&(~S)))|0|0;
		8'h21: nx_Result = (~((D|(P|S))))|0|0|0|0|(D&(P&(~S)))|0|0;
		8'h22: nx_Result = 0|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|0|0;
		8'h23: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|0|0;
		8'h24: nx_Result = 0|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|0;
		8'h25: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|0;
		8'h26: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|0;
		8'h27: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|0;
		8'h28: nx_Result = 0|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h29: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h2a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h2b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h2c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h2d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h2e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h2f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|0;
		8'h30: nx_Result = 0|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h31: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h32: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h33: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h34: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h35: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h36: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h37: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h38: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h39: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h3a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h3b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h3c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h3d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h3e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h3f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|0;
		8'h40: nx_Result = 0|0|0|0|0|0|(P&(S&(~D)))|0;
		8'h41: nx_Result = (~((D|(P|S))))|0|0|0|0|0|(P&(S&(~D)))|0;
		8'h42: nx_Result = 0|(D&(~(P|S)))|0|0|0|0|(P&(S&(~D)))|0;
		8'h43: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|0|(P&(S&(~D)))|0;
		8'h44: nx_Result = 0|0|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|0;
		8'h45: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|0;
		8'h46: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|0;
		8'h47: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|0;
		8'h48: nx_Result = 0|0|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h49: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h4a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h4b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h4c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h4d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h4e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h4f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|0;
		8'h50: nx_Result = 0|0|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h51: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h52: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h53: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h54: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h55: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h56: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h57: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h58: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h59: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h5a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h5b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h5c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h5d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h5e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h5f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|0;
		8'h60: nx_Result = 0|0|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h61: nx_Result = (~((D|(P|S))))|0|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h62: nx_Result = 0|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h63: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h64: nx_Result = 0|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h65: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h66: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h67: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h68: nx_Result = 0|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h69: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h6a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h6b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h6c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h6d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h6e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h6f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h70: nx_Result = 0|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h71: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h72: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h73: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h74: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h75: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h76: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h77: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h78: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h79: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h7a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h7b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h7c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h7d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h7e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h7f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|0;
		8'h80: nx_Result = 0|0|0|0|0|0|0|(D&(P&S));
		8'h81: nx_Result = (~((D|(P|S))))|0|0|0|0|0|0|(D&(P&S));
		8'h82: nx_Result = 0|(D&(~(P|S)))|0|0|0|0|0|(D&(P&S));
		8'h83: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|0|0|(D&(P&S));
		8'h84: nx_Result = 0|0|(S&(~(D|P)))|0|0|0|0|(D&(P&S));
		8'h85: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|0|0|(D&(P&S));
		8'h86: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|0|(D&(P&S));
		8'h87: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|0|(D&(P&S));
		8'h88: nx_Result = 0|0|0|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h89: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h8a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h8b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h8c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h8d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h8e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h8f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|0|(D&(P&S));
		8'h90: nx_Result = 0|0|0|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h91: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h92: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h93: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h94: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h95: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h96: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h97: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h98: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h99: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h9a: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h9b: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h9c: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h9d: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h9e: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'h9f: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|0|(D&(P&S));
		8'ha0: nx_Result = 0|0|0|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha1: nx_Result = (~((D|(P|S))))|0|0|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha2: nx_Result = 0|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha4: nx_Result = 0|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha8: nx_Result = 0|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'ha9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'haa: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'hab: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'hac: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'had: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'hae: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'haf: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|0|(D&(P&S));
		8'hb0: nx_Result = 0|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb1: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb2: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb4: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb8: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hb9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hba: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hbb: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hbc: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hbd: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hbe: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hbf: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|0|(D&(P&S));
		8'hc0: nx_Result = 0|0|0|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc1: nx_Result = (~((D|(P|S))))|0|0|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc2: nx_Result = 0|(D&(~(P|S)))|0|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc4: nx_Result = 0|0|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc8: nx_Result = 0|0|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hc9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hca: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hcb: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hcc: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hcd: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hce: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hcf: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|0|(P&(S&(~D)))|(D&(P&S));
		8'hd0: nx_Result = 0|0|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd1: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd2: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd4: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd8: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hd9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hda: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hdb: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hdc: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hdd: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hde: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'hdf: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|0|(P&(S&(~D)))|(D&(P&S));
		8'he0: nx_Result = 0|0|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he1: nx_Result = (~((D|(P|S))))|0|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he2: nx_Result = 0|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he4: nx_Result = 0|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he8: nx_Result = 0|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'he9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hea: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'heb: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hec: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hed: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hee: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hef: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|0|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf0: nx_Result = 0|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf1: nx_Result = (~((D|(P|S))))|0|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf2: nx_Result = 0|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf3: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf4: nx_Result = 0|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf5: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf6: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf7: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|0|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf8: nx_Result = 0|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hf9: nx_Result = (~((D|(P|S))))|0|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hfa: nx_Result = 0|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hfb: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|0|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hfc: nx_Result = 0|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hfd: nx_Result = (~((D|(P|S))))|0|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hfe: nx_Result = 0|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
		8'hff: nx_Result = (~((D|(P|S))))|(D&(~(P|S)))|(S&(~(D|P)))|(S&(D&(~P)))|(P&(~(D|S)))|(D&(P&(~S)))|(P&(S&(~D)))|(D&(P&S));
    default : nx_Result = 0;
  endcase

//DFF
always@(posedge clk)
  begin
    if(state == IDLE) begin
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
