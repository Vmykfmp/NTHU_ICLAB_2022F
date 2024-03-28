//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

module enigma_part2(clk, srst_n, load, encrypt, crypt_mode, table_idx, code_in, code_out, code_valid);

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
							// Note: We only use rotorA and rotor B in part2.
output reg [6-1:0] code_out;   // encrypted code word (register output)
output reg code_valid;         // 0: non-valid code_out; 1: valid code_out (register output)

parameter IDLE = 2'b00, LOAD = 2'b01, READY = 2'b10;

integer i, j, k;

reg [1:0] state, n_state;
reg [6-1:0] index, n_index;

reg [6-1:0] rotorA_table[0:64-1];
reg [6-1:0] n_rotorA_table[0:64-1];
reg [6-1:0] rotorB_table[0:64-1];
reg [6-1:0] n_rotorB_table[0:64-1];
reg [6-1:0] t_rotorB_table[0:64-1];
reg [6-1:0] reflector_table[0:64-1];

reg [6-1:0] rotA_o;
reg [6-1:0] rotB_o;
reg [6-1:0] ref_o;
reg [6-1:0] rotB_b;

reg [2-1:0] rotA_mode;
reg [3-1:0] rotB_mode;

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
	for (k=63; k>=0; k=k-1) begin
    n_rotorA_table[k] = rotorA_table[k];
    n_rotorB_table[k] = rotorB_table[k];
  end
  n_index = index;
	n_code_out = code_out;
	n_code_valid = code_valid;
	if(state == LOAD) begin
		if(index < 63) n_index = index + 1;
		else n_index = 0;
		case(table_idx)
			2'b01:begin
				if(load) n_rotorA_table[index] = code_in;
        n_rotorB_table[index] = rotorB_table[index];
				n_code_out = 0;
				n_code_valid = 0;
			end
      2'b10:begin
				if(load) n_rotorB_table[index] = code_in;
        n_rotorA_table[index] = rotorA_table[index];
				n_code_out = 0;
				n_code_valid = 0;
			end
			default:begin
				n_rotorA_table[index] = rotorA_table[index];
        n_rotorB_table[index] = rotorB_table[index];
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
      rotB_o = rotorB_table[rotA_o];  
      ref_o = reflector_table[rotB_o];
			//backward
      rotB_b = 0;
      for (j=0; j<64; j=j+1)
			  if(rotorB_table[j] == ref_o) rotB_b = j;
      for (j=0; j<64; j=j+1)
        if(rotorA_table[j] == rotB_b) n_code_out = j;
			//determine rotor mode
			n_code_valid = 1;
      if(!crypt_mode) begin
        rotA_mode = rotA_o%4;
        rotB_mode = rotB_o%8;
      end
      else begin
        rotA_mode = rotB_b%4;
        rotB_mode = ref_o%8;
      end

			//rotA:shift
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
      //rotB_stage1:s-box8
      case(rotB_mode)
        3'd0 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[0+(8*j)];
            t_rotorB_table[1+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[7+(8*j)];
          end
        end
        3'd1 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[1+(8*j)] = rotorB_table[0+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[7+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[6+(8*j)];
          end
        end
        3'd2 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[2+(8*j)];   
            t_rotorB_table[1+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[0+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[7+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[5+(8*j)];
          end
        end
        3'd3 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[0+(8*j)];    
            t_rotorB_table[1+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[7+(8*j)];
          end
        end
        3'd4 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[4+(8*j)];    
            t_rotorB_table[1+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[7+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[0+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[3+(8*j)];
          end
        end
        3'd5 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[5+(8*j)];    
            t_rotorB_table[1+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[7+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[0+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[2+(8*j)];
          end
        end
        3'd6 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[6+(8*j)];    
            t_rotorB_table[1+(8*j)] = rotorB_table[7+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[0+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[1+(8*j)];
          end
        end
        3'd7 : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[7+(8*j)];    
            t_rotorB_table[1+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[0+(8*j)];
          end
        end
        default : begin
          for(j=0; j<8; j=j+1) begin
            t_rotorB_table[0+(8*j)] = rotorB_table[0+(8*j)];    
            t_rotorB_table[1+(8*j)] = rotorB_table[1+(8*j)];
            t_rotorB_table[2+(8*j)] = rotorB_table[2+(8*j)];
            t_rotorB_table[3+(8*j)] = rotorB_table[3+(8*j)];
            t_rotorB_table[4+(8*j)] = rotorB_table[4+(8*j)];
            t_rotorB_table[5+(8*j)] = rotorB_table[5+(8*j)];
            t_rotorB_table[6+(8*j)] = rotorB_table[6+(8*j)];
            t_rotorB_table[7+(8*j)] = rotorB_table[7+(8*j)];
          end
        end
      endcase
      //rotB_stage2:s-box64
      n_rotorB_table[0]  = t_rotorB_table[20];
      n_rotorB_table[1]  = t_rotorB_table[50];
      n_rotorB_table[2]  = t_rotorB_table[8];
      n_rotorB_table[3]  = t_rotorB_table[36];
      n_rotorB_table[4]  = t_rotorB_table[48];
      n_rotorB_table[5]  = t_rotorB_table[26];
      n_rotorB_table[6]  = t_rotorB_table[55];
      n_rotorB_table[7]  = t_rotorB_table[13];

      n_rotorB_table[8]  = t_rotorB_table[44];
      n_rotorB_table[9]  = t_rotorB_table[43];
      n_rotorB_table[10] = t_rotorB_table[10];
      n_rotorB_table[11] = t_rotorB_table[52];
      n_rotorB_table[12] = t_rotorB_table[54];
      n_rotorB_table[13] = t_rotorB_table[25];
      n_rotorB_table[14] = t_rotorB_table[41];
      n_rotorB_table[15] = t_rotorB_table[0];

      n_rotorB_table[16] = t_rotorB_table[63];
      n_rotorB_table[17] = t_rotorB_table[16];
      n_rotorB_table[18] = t_rotorB_table[34];
      n_rotorB_table[19] = t_rotorB_table[6];
      n_rotorB_table[20] = t_rotorB_table[61];
      n_rotorB_table[21] = t_rotorB_table[30];
      n_rotorB_table[22] = t_rotorB_table[7];
      n_rotorB_table[23] = t_rotorB_table[5];

      n_rotorB_table[24] = t_rotorB_table[47];
      n_rotorB_table[25] = t_rotorB_table[17];
      n_rotorB_table[26] = t_rotorB_table[11];
      n_rotorB_table[27] = t_rotorB_table[38];
      n_rotorB_table[28] = t_rotorB_table[12];
      n_rotorB_table[29] = t_rotorB_table[27];
      n_rotorB_table[30] = t_rotorB_table[3];
      n_rotorB_table[31] = t_rotorB_table[9];

      n_rotorB_table[32] = t_rotorB_table[35];
      n_rotorB_table[33] = t_rotorB_table[14];
      n_rotorB_table[34] = t_rotorB_table[40];
      n_rotorB_table[35] = t_rotorB_table[56];
      n_rotorB_table[36] = t_rotorB_table[32];
      n_rotorB_table[37] = t_rotorB_table[57];
      n_rotorB_table[38] = t_rotorB_table[49];
      n_rotorB_table[39] = t_rotorB_table[21];

      n_rotorB_table[40] = t_rotorB_table[19];
      n_rotorB_table[41] = t_rotorB_table[45];
      n_rotorB_table[42] = t_rotorB_table[18];
      n_rotorB_table[43] = t_rotorB_table[60];
      n_rotorB_table[44] = t_rotorB_table[15];
      n_rotorB_table[45] = t_rotorB_table[22];
      n_rotorB_table[46] = t_rotorB_table[53];
      n_rotorB_table[47] = t_rotorB_table[4];

      n_rotorB_table[48] = t_rotorB_table[1];
      n_rotorB_table[49] = t_rotorB_table[46];
      n_rotorB_table[50] = t_rotorB_table[2];
      n_rotorB_table[51] = t_rotorB_table[62];
      n_rotorB_table[52] = t_rotorB_table[28];
      n_rotorB_table[53] = t_rotorB_table[31];
      n_rotorB_table[54] = t_rotorB_table[23];
      n_rotorB_table[55] = t_rotorB_table[58];

      n_rotorB_table[56] = t_rotorB_table[29];
      n_rotorB_table[57] = t_rotorB_table[33];
      n_rotorB_table[58] = t_rotorB_table[51];
      n_rotorB_table[59] = t_rotorB_table[42];
      n_rotorB_table[60] = t_rotorB_table[24];
      n_rotorB_table[61] = t_rotorB_table[39];
      n_rotorB_table[62] = t_rotorB_table[37];
      n_rotorB_table[63] = t_rotorB_table[59];
		end
	end
	else begin
		for (k=63; k>=0; k=k-1) begin
      n_rotorA_table[k] = 0;
      n_rotorB_table[k] = 0;
    end
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
		for(i=0;i<64;i=i+1) begin
      rotorA_table[i] <= 0;
      rotorB_table[i] <= 0;
    end
	end
	else begin
		state <= n_state;
		index <= n_index;
		code_out <= n_code_out;
		code_valid <= n_code_valid;
		for(i=0;i<64;i=i+1) begin
      rotorA_table[i] <= n_rotorA_table[i];
      rotorB_table[i] <= n_rotorB_table[i];
    end
  end
end

endmodule
