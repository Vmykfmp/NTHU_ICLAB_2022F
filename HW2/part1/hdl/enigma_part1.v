//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

module enigma_part1(clk, srst_n, load, encrypt, crypt_mode, table_idx, code_in, code_out, code_valid);

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
							// Note: We only use rotorA in part1.

output reg [6-1:0] code_out;   // encrypted code word (register output)
output reg code_valid;         // 0: non-valid code_out; 1: valid code_out (register output)

localparam IDLE = 2'b00, LOAD = 2'b01, READY = 2'b10;
integer i, j, k;

reg [1:0] state, n_state;
reg [6-1:0] index, n_index;

reg [6-1:0] rotorA_table[0:64-1];
reg [6-1:0] n_rotorA_table[0:64-1];
reg [6-1:0] reflector_table[0:64-1];

reg [6-1:0] rotA_o;
reg [6-1:0] ref_o;
reg [6-1:0] last_A;
reg [2-1:0] rotA_mode;
reg [6-1:0] n_code_out;
reg n_code_valid;

/// FSM ///
always @*  begin
	case(state)
		IDLE: n_state = LOAD;
		LOAD: begin
			if (load)  n_state = LOAD;
			else      n_state = READY;
		end
		READY: n_state = READY;
		default: n_state = LOAD;
	endcase

	for (i=0; i<64; i=i+1) reflector_table[i] = 63-i;
end

/// ENGINE ///
always @* begin
	for (k=63; k>=0; k=k-1) n_rotorA_table[k] = rotorA_table[k];
	n_index = index;
	n_code_out = code_out;
	n_code_valid = code_valid;
	if(state == LOAD) begin
		if(index < 63) n_index = index + 1;
		else n_index = 6'd0;
		case(table_idx)
			2'b01:begin
				if(load) n_rotorA_table[index] = code_in;
				n_code_out = 0;
				n_code_valid = 0;
			end
			default:begin
				n_rotorA_table[index] = rotorA_table[index];
				n_code_out = 0;
				n_code_valid = 0;
			end
		endcase
	end
	else if(state == READY) begin
		n_index = 0;
		if(encrypt) begin
			//forward
			rotA_o = rotorA_table[code_in];
			ref_o = reflector_table[rotA_o];
			//backward
			for (j=0; j<64; j=j+1)
				if(rotorA_table[j] == ref_o) n_code_out = j;	
			//determine rotor mode
			n_code_valid = 1;
			if(!crypt_mode) rotA_mode = rotA_o%4;
			else rotA_mode = ref_o%4;
			//change rotor
			case (rotA_mode)
				2'b01:begin
					n_rotorA_table[0] = rotorA_table[63];
					for (k=62; k>=0; k=k-1) n_rotorA_table[k+1] = rotorA_table[k];
				end
				2'b10:begin
					n_rotorA_table[0] = rotorA_table[62];
					n_rotorA_table[1] = rotorA_table[63];
					for (k=61; k>=0; k=k-1) n_rotorA_table[k+2] = rotorA_table[k];
				end
				2'b11:begin
					n_rotorA_table[0] = rotorA_table[61];
					n_rotorA_table[1] = rotorA_table[62];
					n_rotorA_table[2] = rotorA_table[63];
					for (k=60; k>=0; k=k-1) n_rotorA_table[k+3] = rotorA_table[k];
				end
				default:begin
					for (k=63; k>=0; k=k-1) n_rotorA_table[k] = rotorA_table[k];
				end
			endcase
		end
	end
	else begin
		for (k=63; k>=0; k=k-1) n_rotorA_table[k] = 0;
		n_index = 0;
		n_code_out = 0;
		n_code_valid = 0;
	end
end

always @(posedge clk) begin
	if (~srst_n) begin
		state <= IDLE;
		index <= 0;
		code_out <= 0;
		code_valid <= 0;
		for(i=0;i<64;i=i+1) rotorA_table[i] <= 0;
	end
	else begin
		state <= n_state;
		index <= n_index;
		code_out <= n_code_out;
		code_valid <= n_code_valid;
		for(i=0;i<64;i=i+1) rotorA_table[i] <= n_rotorA_table[i];
	end
end

endmodule
