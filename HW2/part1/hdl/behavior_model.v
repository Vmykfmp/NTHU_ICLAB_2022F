//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

module behavior_model(clk,srst_n,load,encrypt,crypt_mode,table_idx,code_in,code_out,code_valid);
input clk;               // clock input
input srst_n;            // synchronous reset (active low)
input load;              // load control signal (level sensitive). 0/1: inactive/active
                         // effective in ST_IDLE and ST_LOAD states

input encrypt;           // encrypt control signal (level sensitive). 0/1: inactive/active
                         // effective in ST_READY state

input crypt_mode;        // 0: encrypt; 1:decrypt;

input [2-1:0] table_idx; // table_idx indicates which rotor to be load
						 // 2'b00: plug board
						 // 2'b01: rotorA
						 // 2'b10: rotorB

input [6-1:0] code_in;		// When load is active, then code_in is input of rotors.
							// When encrypy is active, then code_in is input of code words.
							// Note: We only use rotorA in this part.

output reg [6-1:0] code_out;   // encrypted code word (register output)
output reg code_valid;         // 0: non-valid code_out; 1: valid code_out (register output)

parameter IDLE = 2'b00, LOAD = 2'b01, READY = 2'b10;
integer i, j, k;

reg [1:0] state, n_state;
reg [6-1:0] rotorA_table[0:64-1];
reg [6-1:0] reflector_table[0:64-1];
reg [6-1:0] rotA_o;
reg [6-1:0] ref_o;
reg [6-1:0] last_A;
reg [2-1:0] rotA_mode;

/// FSM ///
always @*  begin
	if (~srst_n) @(posedge clk) state = IDLE;

	case(state)
		IDLE: @(posedge clk) state = LOAD;
		LOAD: begin
			if (load) @(posedge clk) state = LOAD;
			else      @(posedge clk) state = READY;
		end
		READY: state = READY;
	endcase

	for (i=0; i<64; i = i+1) reflector_table[i] = 63-i;

end

/// ENGINE ///
initial begin
	// Load Table
	$readmemh("../sim/rotor/rotorA.dat",rotorA_table);
	wait(encrypt);

	// encrypt or decrypt
	for(i=0;i<27;i=i+1) begin
		@(posedge clk)
		rotA_o = rotorA_table[code_in];
		ref_o = reflector_table[rotA_o];

		for (j=0; j<64; j=j+1)
			if(rotorA_table[j] == ref_o) code_out = j;

		code_valid = 1;
		rotA_mode = rotA_o%4;

		for (j=0; j<rotA_mode; j=j+1)begin
			last_A = rotorA_table[63];
			for (k=62; k>=0; k=k-1) begin
				rotorA_table[k+1] = rotorA_table[k];
			end
			rotorA_table[0]= last_A;
		end

	end
end

endmodule
