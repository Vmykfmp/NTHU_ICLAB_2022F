//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

`timescale 1ns/100ps

`define CYCLE 10

`define MAX_QRCode 4
`define END_CYCLE 100000000

`define PAT_L 0
`define PAT_U 99

`ifdef RANK_A
	`define RANK "A"
	`define NUM_PAT 300
	`define TOTAL_QRCode 750
	`define golden_num_filepath "./golden/golden_num_rank_A.dat"
	`define golden_len_filepath "./golden/golden_length_rank_A.dat"
	`define golden_loc_filepath "./golden/golden_loc_rank_A.dat"
	`define golden_text_filepath "./golden/golden_text_rank_A.dat"
`elsif RANK_B
	`define RANK "B"
	`define NUM_PAT 100
	`define TOTAL_QRCode 200
	`define golden_num_filepath "./golden/golden_num_rank_B.dat"
	`define golden_len_filepath "./golden/golden_length_rank_B.dat"
	`define golden_loc_filepath "./golden/golden_loc_rank_B.dat"
	`define golden_text_filepath "./golden/golden_text_rank_B.dat"
`elsif RANK_C
	`define RANK "C"
	`define NUM_PAT 100
	`define TOTAL_QRCode 100
	`define golden_num_filepath "./golden/golden_num_rank_C.dat"
	`define golden_len_filepath "./golden/golden_length_rank_C.dat"
	`define golden_loc_filepath "./golden/golden_loc_rank_C.dat"
	`define golden_text_filepath "./golden/golden_text_rank_C.dat"
`elsif RANK_D
	`define RANK "D"
	`define NUM_PAT 100
	`define TOTAL_QRCode 100
	`define golden_num_filepath "./golden/golden_num_rank_D.dat"
    `define golden_len_filepath "./golden/golden_length_rank_D.dat"
	`define golden_loc_filepath "./golden/golden_loc_rank_D.dat"
	`define golden_text_filepath "./golden/golden_text_rank_D.dat"
`else  // RANK_D is default if not specified
	`define RANK "D"
	`define NUM_PAT 100
	`define TOTAL_QRCode 100
	`define golden_num_filepath "./golden/golden_num_rank_D.dat"
    `define golden_len_filepath "./golden/golden_length_rank_D.dat"
	`define golden_loc_filepath "./golden/golden_loc_rank_D.dat"
	`define golden_text_filepath "./golden/golden_text_rank_D.dat"
`endif

module test_qrcode_decoder;

// RTL instantiation
reg clk;
reg srst_n;
reg start;
wire sram_rdata;

wire [11:0] sram_raddr;
wire [5:0] loc_y;
wire [5:0] loc_x;
wire [7:0] decode_text;
wire valid;
wire finish;

qrcode_decoder qrcode_decoder_U0(
	.clk(clk),
	.srst_n(srst_n),
	.start(start),
	.sram_rdata(sram_rdata),
	.sram_raddr(sram_raddr),
	.loc_y(loc_y),
	.loc_x(loc_x),
	.decode_text(decode_text),
	.valid(valid),
	.finish(finish)
);

// SRAM instantiation
sram_4096x1b  sram_4096x1b_U0(
	.clk(clk),
	.csb(1'b0),
	.wsb(1'b1),
	.wdata(1'b0), 
	.waddr(12'd0), 
	.raddr(sram_raddr),
	.rdata(sram_rdata)
);

// dump waveform
initial begin
	$fsdbDumpfile("qrcode_decoder.fsdb");
	$fsdbDumpvars("+mda");
end

// create clk
initial begin
    clk = 1;
    while(1) #(`CYCLE/2) clk = ~clk;
end

// cycle accumulator
integer total_cycle;
initial begin
	total_cycle = 0;
	while(1) begin
		@(posedge clk);
		total_cycle = total_cycle + 1;
	end
end

//-------------------- main --------------------
reg [7:0] golden_len [0:`TOTAL_QRCode-1];
reg [5:0] golden_loc_y [0:`TOTAL_QRCode-1];
reg [5:0] golden_loc_x [0:`TOTAL_QRCode-1];
reg [17*8-1:0] golden_text [0:`TOTAL_QRCode-1];
reg [3:0] num_qrcode_in_pat [0:`NUM_PAT];
reg passed_pat [0:`NUM_PAT];
integer i, j, k;
integer idx;

reg [7:0] this_golden_len [0:`MAX_QRCode-1];
reg [5:0] this_golden_loc_y [0:`MAX_QRCode-1];
reg [5:0] this_golden_loc_x [0:`MAX_QRCode-1];
reg [17*8-1:0] this_golden_text [0:`MAX_QRCode-1];
reg [7:0] hw_len [0:`MAX_QRCode-1];
reg hw_found_flag [0:`MAX_QRCode-1];
reg unmatched [0:`MAX_QRCode-1];
reg detected;
integer total_hw_found;

reg err_text_flag;
reg err_loc_flag;
reg err_len_flag;
reg err_num_flag;

integer total_err_pat;

initial begin
	$write("\n");
	// check if PAT_L and PAT_U are both valid
	if((`PAT_L < 0) || (`PAT_L > `NUM_PAT-1) || (`PAT_U < 0) || (`PAT_U > `NUM_PAT-1)) begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                                             X");
		$display("X   Error!!! PAT_L and PAT_U should be within the range [0, %3d] for Rank %0s   X", `NUM_PAT-1, `RANK);
		$display("X                                                                             X");
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$finish;
	end
	else if(`PAT_L > `PAT_U) begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                        X");
		$display("X   Error!!! PAT_L should be smaller or equal to PAT_U   X");
		$display("X                                                        X");
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$finish;		
	end

	read_golden;  // read golden files
	//display_golden;  // display golden results of all patterns

	// whole simulation process
	total_err_pat = 0;
	for(i=`PAT_L; i<=`PAT_U; i=i+1) begin
		
		sram_4096x1b_U0.bmp2sram(i, `RANK);  // load pattern (.bmp) into SRAM
		//sram_4096x1b_U0.display_sram;  // display the content inside SRAM

		// compute index
		idx = 0;
		for(j=0; j<i; j=j+1) begin
			idx = idx + num_qrcode_in_pat[j];
		end

		// assign golden result of this pattern
		for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
			this_golden_len[j] = golden_len[idx];
			this_golden_loc_y[j] = golden_loc_y[idx];
			this_golden_loc_x[j] = golden_loc_x[idx];
			this_golden_text[j] = golden_text[idx];
			hw_len[j] = 0;
			hw_found_flag[j] = 0;
			unmatched[j] = 0;
			idx = idx + 1;
		end

		// reset error flag for this pattern
		err_text_flag = 0;
		err_loc_flag = 0;
		err_len_flag = 0;
		err_num_flag = 0;

		// simulation start for a test pattern
		$display("---------- Pattern No. %02d ----------", i);

		srst_n = 1;
		start = 0;
		@(negedge clk); srst_n = 0;
		@(negedge clk);
		@(negedge clk); srst_n = 1; start = 1;
		@(negedge clk); start = 0;

		// output comparison
		while(!finish) begin
			@(negedge clk);
			if(valid) begin
				detected = 0;
				for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
					if(loc_y === this_golden_loc_y[j] && loc_x === this_golden_loc_x[j]) begin
						detected = 1;
						if(hw_found_flag[j] == 0) begin
							$write("\n");
							$display("QR Code at (loc_y, loc_x)=(%0d, %0d) is detected.", loc_y, loc_x);
							$write("Golden decoded text: ");
							for(k=0; k<this_golden_len[j]; k=k+1) begin
								$write("%c", this_golden_text[j][k*8 +: 8]);
							end
							$write("\n");
							$write("  Your decoded text: ");
							hw_found_flag[j] = 1;
						end
						$write("%c", decode_text);
						//--- check if output text is wrong ---
						if(decode_text !== this_golden_text[j][hw_len[j]*8 +: 8]) begin
							err_text_flag = 1;
							unmatched[j] = 1;
							//$display("<-- this character is wrong!  ");
						end
						hw_len[j] = hw_len[j] + 1;
					end
				end
				//--- check if output location is wrong ---
				if(detected == 0) begin
					err_loc_flag = 1;
					$write("\n\n");
					$display("No QR Code at (loc_y, loc_x)=(%0d, %0d) in this pattern!", loc_y, loc_x);
				end
			end
    	end

		$write("\n");
		// error message of text correctness
		if(err_text_flag) begin
			$write("\n");
			$display("Text Correctness:");
			for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
				if(unmatched[j]) begin
					$display("    Output text of QR Code at (loc_y, loc_x)=(%0d, %0d) is wrong!", 
						this_golden_loc_y[j], this_golden_loc_x[j]);
				end
			end
		end

		//--- check if output text length is wrong ---
		for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
			if(hw_len[j] != this_golden_len[j]) begin
				err_len_flag = 1;	
			end
		end
		if(err_len_flag) begin
			// error message
			$write("\n");
			$display("Text Length:");
			for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
				if(hw_len[j] != this_golden_len[j]) begin
					$display("    Output text length of QR Code at (loc_y, loc_x)=(%0d, %0d) is wrong!",
						this_golden_loc_y[j], this_golden_loc_x[j]);
					$display("    Golden text length is %0d, but your output text length is %0d. (Your valid goes high for %0d times for this QR Code)",
						this_golden_len[j], hw_len[j], hw_len[j]);
				end	
			end
		end

		//--- check if all QR Codes in the pattern are found ---
		total_hw_found = 0;
		for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
			if(hw_found_flag[j] == 1)
				total_hw_found = total_hw_found + 1;
		end
		if(total_hw_found != num_qrcode_in_pat[i]) begin
			err_num_flag = 1;
			// error message
			$write("\n");
			$display("Number of QR Code:");
			$display("    There are %0d QR Codes in this pattern, but only %0d of them are found.", 
				num_qrcode_in_pat[i], total_hw_found);
		end

		// summary of this pattern
		if(!err_text_flag & !err_loc_flag & !err_len_flag & !err_num_flag) begin
			passed_pat[i] = 1;
			$write("\n");
			$display("Pattern No. %02d is successfully passed \\(O v O)/", i);
			$write("\n");
		end
		else begin
			passed_pat[i] = 0;
			$write("\n");
			$display("Pattern No. %02d is failed... (T ~ T)", i);
			$display("There is something wrong. Please check above error message.");
			total_err_pat = total_err_pat + 1;
			$write("\n");
			//$finish
		end
	end

	// summary of all patterns
	$write("\n");
	$display("====================== Summary of Rank %0s =======================", `RANK);
	if(total_err_pat == 0) begin
		$display("Congratulation! All patterns are successfully passed! \\(O v O)/");
		$display("Total cycle count C = %0d", total_cycle);
		$write("\n");
	end
	else begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                 X");
		$display("X   Error!!! %3d patterns are failed... (T ~ T)   X", total_err_pat);
		$display("X                                                 X");
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$write("\n");
		for(i=0; i<`NUM_PAT; i=i+1) begin
			if(!passed_pat[i]) begin
				$display("Pattern No. %02d is failed... (T ~ T)", i);
			end
		end
		$write("\n");
	end

	// check if all patterns are simulated
	if((`PAT_L != 0) || (`PAT_U != `NUM_PAT-1)) begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                                                             X");
		$display("X   Warning!!! You only simulate Pattern No. %3d to No. %3d                                   X", `PAT_L, `PAT_U);
		$display("X   There are total %3d patterns in Rank %0s.                                                   X", `NUM_PAT, `RANK);
		$display("X   Remember to simulate all patterns and check if all are passed.                            X");
		$display("X   The total cycle count C in the PI should be the result when all patterns are simulated.   X");
		$display("X                                                                                             X");
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$write("\n");
	end

	$finish;
end

// terminate simulation if it takes too long
initial begin
	#(`CYCLE * `END_CYCLE);
	$write("\n");
	$display("======================================================");
	$display("   Error!!! Simulation time is too long...            ");
	$display("   There might be something wrong in your code.       ");
	$display("   If your design really needs such a long time,      ");
	$display("   increase the END_CYCLE setting in the testbench.   ");
 	$display("======================================================");
	$write("\n");
 	$finish;
end

//-------------------- task --------------------
task read_golden;
	reg [15:0] temp_loc [0:`TOTAL_QRCode-1];
	reg [7:0] char_in;
	reg [17*8-1:0] temp_string;
	integer text_file_in;
	integer i, j, k;
	integer cnt;

	begin
		$readmemh(`golden_num_filepath, num_qrcode_in_pat);
		$readmemh(`golden_len_filepath, golden_len);
		$readmemh(`golden_loc_filepath, temp_loc);
		for(i=0; i<`TOTAL_QRCode; i=i+1) begin
			golden_loc_y[i] = temp_loc[i][13:8];
			golden_loc_x[i] = temp_loc[i][5:0];
		end
		
		text_file_in = $fopen(`golden_text_filepath, "r");
		cnt = 0;
		for(i=0; i<`NUM_PAT; i=i+1) begin
			for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
				for(k=0; k<golden_len[cnt]; k=k+1) begin
					char_in = $fgetc(text_file_in);
					temp_string[k*8 +: 8] = char_in;
				end
				golden_text[cnt] = temp_string;
				char_in = $fgetc(text_file_in);  // skip newline at the end of a text pattern
				cnt = cnt + 1;
			end
			char_in = $fgetc(text_file_in);  // skip newline which is used to distinguish different patterns
		end

		$fclose(text_file_in);
  	end
endtask

task display_golden;
	integer i, j, k;
	integer cnt;

	begin
		cnt = 0;
		for(i=0; i<`NUM_PAT; i=i+1) begin
			$display("pattern %0d:", i);
			for(j=0; j<num_qrcode_in_pat[i]; j=j+1) begin
				$write("    ");
				$write("(%2d, %2d)  ", golden_loc_y[cnt], golden_loc_x[cnt]);
				$write("%2d-byte  ", golden_len[cnt]);
				for(k=0; k<golden_len[cnt]; k=k+1) begin
					$write("%c", golden_text[cnt][k*8 +: 8]);
				end
				$write("\n");
				cnt = cnt + 1;
			end
		end
	end
endtask

endmodule