/*
* Module      : rop3_lut16
* Description : Implement this module using the look-up table (LUT).
*               This module should support all the 15-modes listed in table-1.
*               For modes not in the table-1, set the Result to 0.
* Notes       : Please remember to make the bit-length of {Bitmap, Result} parameterizable.
*/

module rop3_lut16
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
    8'h00 : nx_Result = 0;
    8'h11 : nx_Result = ~(D | S);
    8'h33 : nx_Result = ~S;
    8'h44 : nx_Result = S & (~D);
    8'h55 : nx_Result = ~D;
    8'h5A : nx_Result = D ^ P;
    8'h66 : nx_Result = D ^ S;
    8'h88 : nx_Result = D & S;
    8'hBB : nx_Result = D | (~S);
    8'hC0 : nx_Result = P & S;
    8'hCC : nx_Result = S;
    8'hEE : nx_Result = D | S;
    8'hF0 : nx_Result = P;
    8'hFB : nx_Result = D | P | (~S);
    8'hFF : nx_Result = ~0;
    default : nx_Result = 0;
  endcase

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
