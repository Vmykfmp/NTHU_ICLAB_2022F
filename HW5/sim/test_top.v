//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

`timescale 1ns/100ps


`define PAT_L 0
`define PAT_U 1
`define NUM_PAT (`PAT_U-`PAT_L+1)

`define PAT_NAME_LENGTH 4
`define CYCLE 10
`define END_CYCLES 100000000 // you can enlarge the cycle count limit for longer simulation
`define FLAG_VERBOSE 0   
`define FLAG_SHOWNUM 0
`define FLAG_DUMPWV 0

module test_top;
localparam CH_NUM = 4;
localparam ACT_PER_ADDR = 4;
localparam BW_PER_ACT = 12;
localparam BW_PER_SRAM_GROUP_ADDR = CH_NUM*ACT_PER_ADDR*BW_PER_ACT; // 4 x 4 x 12 = 192
localparam DW_WEIGHT_PER_ADDR = 9, DW_BIAS_PER_ADDR = 1;
localparam PW_WEIGHT_PER_ADDR = 1, PW_BIAS_PER_ADDR = 1;
localparam BW_PER_PARAM = 8;
localparam Pattern_N = 28*28;

// ===== test layer selection ===== //
/*
    If you want to test the functionality of CONV1_dw layer, pull up the "valid" signal after finish calculating CONV1_dw layer. 
    Then execute the following command for simulation:
        vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs.log +define+TEST_CONV1_DW
    You can test other layers in similar ways. If you do not specify the testing layer as follows
        vcs -R +v2k -full64 -f sim.f -debug_acc -l vcs.log ,
    the testbench will check the answers of the final layers (CONV3_POOL)
*/

localparam UNSHUFFLE = 3'd0, CONV1_DW = 3'd1, CONV1_PW = 3'd2, CONV2_DW = 3'd3, CONV2_PW = 3'd4, CONV3_POOL = 3'd5;

localparam A0=0, A1=1, A2=2, A3=3, B0=4, B1=5, B2=6, B3=7;

integer test_layer;

initial begin
    `ifdef TEST_UNSHUFFLE
        test_layer = UNSHUFFLE;
    `elsif TEST_CONV1_DW
        test_layer = CONV1_DW;
    `elsif TEST_CONV1_PW
        test_layer = CONV1_PW;
    `elsif TEST_CONV2_DW
        test_layer = CONV2_DW;
    `elsif TEST_CONV2_PW
        test_layer = CONV2_PW;
    `else
        test_layer = CONV3_POOL;
    `endif
end

integer i;
// ===== pattern files ===== // 
reg [28*8-1:0] unshuffle_a0_golden_file, unshuffle_a1_golden_file, unshuffle_a2_golden_file, unshuffle_a3_golden_file;
reg [27*8-1:0] conv1_dw_b0_golden_file,  conv1_dw_b1_golden_file, conv1_dw_b2_golden_file, conv1_dw_b3_golden_file;
reg [27*8-1:0] conv1_pw_a0_golden_file, conv1_pw_a1_golden_file, conv1_pw_a2_golden_file, conv1_pw_a3_golden_file;
reg [27*8-1:0] conv2_dw_b0_golden_file,  conv2_dw_b1_golden_file, conv2_dw_b2_golden_file, conv2_dw_b3_golden_file;
reg [27*8-1:0] conv2_pw_a0_golden_file, conv2_pw_a1_golden_file, conv2_pw_a2_golden_file, conv2_pw_a3_golden_file;
reg [29*8-1:0] conv3_pool_b0_golden_file, conv3_pool_b1_golden_file, conv3_pool_b2_golden_file, conv3_pool_b3_golden_file;

// ===== module I/O ===== //
reg clk;
reg srst_n;
reg enable;
wire valid;

wire [DW_WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_weight; // 9 x 8 = 72
wire [10-1:0] sram_raddr_weight; // ceil(log2(784)) = 10

wire [DW_BIAS_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_bias; // 1 x 8 = 8
wire [7-1:0] sram_raddr_bias; // ceil(log2(88)) = 7

wire sram_wen_a0;
wire sram_wen_a1;
wire sram_wen_a2;
wire sram_wen_a3;
wire sram_wen_b0;
wire sram_wen_b1;
wire sram_wen_b2;
wire sram_wen_b3;

wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_a0;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_a1;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_a2;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_a3;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_b0;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_b1;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_b2;
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_rdata_b3;

wire [6-1:0] sram_raddr_a0;
wire [6-1:0] sram_raddr_a1;
wire [6-1:0] sram_raddr_a2;
wire [6-1:0] sram_raddr_a3;
wire [5-1:0] sram_raddr_b0;
wire [5-1:0] sram_raddr_b1;
wire [5-1:0] sram_raddr_b2;
wire [5-1:0] sram_raddr_b3;

wire [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_a;  
wire [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_b;  

wire [6-1:0] sram_waddr_a; // SRAM A addr (0~35)
wire [5-1:0] sram_waddr_b; // SRAM B addr (0~17)

wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_wdata_a;  
wire [BW_PER_SRAM_GROUP_ADDR-1:0] sram_wdata_b;  

// ===== instantiation ===== //
Convnet_top #(
.CH_NUM(CH_NUM),
.ACT_PER_ADDR(ACT_PER_ADDR),
.BW_PER_ACT(BW_PER_ACT),
.WEIGHT_PER_ADDR(DW_WEIGHT_PER_ADDR), 
.BIAS_PER_ADDR(DW_BIAS_PER_ADDR),
.BW_PER_PARAM(BW_PER_PARAM)
)
Conv_top (
.clk(clk),
.srst_n(srst_n),
.enable(enable),
.valid(valid),

.sram_rdata_a0(sram_rdata_a0),
.sram_rdata_a1(sram_rdata_a1),
.sram_rdata_a2(sram_rdata_a2),
.sram_rdata_a3(sram_rdata_a3),
.sram_rdata_b0(sram_rdata_b0),
.sram_rdata_b1(sram_rdata_b1),
.sram_rdata_b2(sram_rdata_b2),
.sram_rdata_b3(sram_rdata_b3),
.sram_rdata_weight(sram_rdata_weight),
.sram_rdata_bias(sram_rdata_bias),


.sram_raddr_a0(sram_raddr_a0),
.sram_raddr_a1(sram_raddr_a1),
.sram_raddr_a2(sram_raddr_a2),
.sram_raddr_a3(sram_raddr_a3),
.sram_raddr_b0(sram_raddr_b0),
.sram_raddr_b1(sram_raddr_b1),
.sram_raddr_b2(sram_raddr_b2),
.sram_raddr_b3(sram_raddr_b3),
.sram_raddr_weight(sram_raddr_weight),
.sram_raddr_bias(sram_raddr_bias),

.sram_wen_a0(sram_wen_a0),
.sram_wen_a1(sram_wen_a1),
.sram_wen_a2(sram_wen_a2),
.sram_wen_a3(sram_wen_a3),
.sram_wen_b0(sram_wen_b0),
.sram_wen_b1(sram_wen_b1),
.sram_wen_b2(sram_wen_b2),
.sram_wen_b3(sram_wen_b3),

.sram_wordmask_a(sram_wordmask_a),
.sram_wordmask_b(sram_wordmask_b),

.sram_waddr_a(sram_waddr_a),
.sram_wdata_a(sram_wdata_a),
.sram_waddr_b(sram_waddr_b),
.sram_wdata_b(sram_wdata_b)

);

// ===== sram connection ===== //
// SRAM for PARAM
sram_784x72b sram_784x72b_weight(
.clk(clk),
.csb(1'b0),
.wsb(1'b1),
.wdata(72'd0), 
.waddr(10'd0), 
.raddr(sram_raddr_weight), 
.rdata(sram_rdata_weight)
);
sram_88x8b sram_88x8b_bias(
.clk(clk),
.csb(1'b0),
.wsb(1'b1),
.wdata(8'd0), 
.waddr(7'd0), 
.raddr(sram_raddr_bias), 
.rdata(sram_rdata_bias)
);
// SRAM A
sram_36x192b sram_36x192b_a0(
.clk(clk),
.wordmask(sram_wordmask_a),
.csb(1'b0),
.wsb(sram_wen_a0),
.wdata(sram_wdata_a), 
.waddr(sram_waddr_a), 
.raddr(sram_raddr_a0), 
.rdata(sram_rdata_a0)
);
sram_36x192b sram_36x192b_a1(
.clk(clk),
.wordmask(sram_wordmask_a),
.csb(1'b0),
.wsb(sram_wen_a1),
.wdata(sram_wdata_a), 
.waddr(sram_waddr_a), 
.raddr(sram_raddr_a1), 
.rdata(sram_rdata_a1)
);
sram_36x192b sram_36x192b_a2(
.clk(clk),
.wordmask(sram_wordmask_a),
.csb(1'b0),
.wsb(sram_wen_a2),
.wdata(sram_wdata_a), 
.waddr(sram_waddr_a), 
.raddr(sram_raddr_a2), 
.rdata(sram_rdata_a2)
);
sram_36x192b sram_36x192b_a3(
.clk(clk),
.wordmask(sram_wordmask_a),
.csb(1'b0),
.wsb(sram_wen_a3),
.wdata(sram_wdata_a), 
.waddr(sram_waddr_a), 
.raddr(sram_raddr_a3), 
.rdata(sram_rdata_a3)
);
// SRAM B
sram_18x192b sram_18x192b_b0(
.clk(clk),
.wordmask(sram_wordmask_b),
.csb(1'b0),
.wsb(sram_wen_b0),
.wdata(sram_wdata_b), 
.waddr(sram_waddr_b), 
.raddr(sram_raddr_b0), 
.rdata(sram_rdata_b0)
);
sram_18x192b sram_18x192b_b1(
.clk(clk),
.wordmask(sram_wordmask_b),
.csb(1'b0),
.wsb(sram_wen_b1),
.wdata(sram_wdata_b), 
.waddr(sram_waddr_b), 
.raddr(sram_raddr_b1), 
.rdata(sram_rdata_b1)
);
sram_18x192b sram_18x192b_b2(
.clk(clk),
.wordmask(sram_wordmask_b),
.csb(1'b0),
.wsb(sram_wen_b2),
.wdata(sram_wdata_b), 
.waddr(sram_waddr_b), 
.raddr(sram_raddr_b2), 
.rdata(sram_rdata_b2)
);
sram_18x192b sram_18x192b_b3(
.clk(clk),
.wordmask(sram_wordmask_b),
.csb(1'b0),
.wsb(sram_wen_b3),
.wdata(sram_wdata_b), 
.waddr(sram_waddr_b), 
.raddr(sram_raddr_b3), 
.rdata(sram_rdata_b3)
);

// ===== waveform dumpping ===== //

initial begin
    if(`FLAG_DUMPWV)begin
        $fsdbDumpfile("hw5_digit_classifier.fsdb");
        $fsdbDumpvars("+mda");
    end
end

// ===== parameters & golden answers ===== //
// unshuffled image
reg [BW_PER_SRAM_GROUP_ADDR-1:0] unshuffle_ans_a0 [0:16-1];  
reg [BW_PER_SRAM_GROUP_ADDR-1:0] unshuffle_ans_a1 [0:12-1];  
reg [BW_PER_SRAM_GROUP_ADDR-1:0] unshuffle_ans_a2 [0:12-1];  
reg [BW_PER_SRAM_GROUP_ADDR-1:0] unshuffle_ans_a3 [0:9-1];  

// conv1 dw
reg [DW_WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] conv1_dw_w [0:4-1];
reg [DW_BIAS_PER_ADDR*BW_PER_PARAM-1:0] conv1_dw_b [0:4-1];
reg [BW_PER_SRAM_GROUP_ADDR-1:0] conv1_dw_ans_b0 [0:9-1], conv1_dw_ans_b1 [0:9-1], conv1_dw_ans_b2 [0:9-1], conv1_dw_ans_b3 [0:9-1];    

// conv1 pw
reg [DW_WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] conv1_pw_w [0:2-1];
reg [DW_BIAS_PER_ADDR*BW_PER_PARAM-1:0] conv1_pw_b [0:4-1];
reg [BW_PER_SRAM_GROUP_ADDR-1:0] conv1_pw_ans_a0[0:9-1], conv1_pw_ans_a1[0:9-1], conv1_pw_ans_a2[0:9-1], conv1_pw_ans_a3[0:9-1];

// conv2 dw
reg [DW_WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] conv2_dw_w [0:4-1];
reg [DW_BIAS_PER_ADDR*BW_PER_PARAM-1:0] conv2_dw_b [0:4-1];
reg [BW_PER_SRAM_GROUP_ADDR-1:0] conv2_dw_ans_b0 [0:9-1], conv2_dw_ans_b1 [0:6-1], conv2_dw_ans_b2 [0:6-1], conv2_dw_ans_b3 [0:4-1];    

// conv2 pw
reg [DW_WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] conv2_pw_w [0:6-1];
reg [DW_BIAS_PER_ADDR*BW_PER_PARAM-1:0] conv2_pw_b [0:12-1];
reg [BW_PER_SRAM_GROUP_ADDR-1:0] conv2_pw_ans_a0[0:27-1], conv2_pw_ans_a1[0:18-1], conv2_pw_ans_a2[0:18-1], conv2_pw_ans_a3[0:12-1];

// conv3 POOL out
reg [DW_WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] conv3_w [0:768-1];
reg [DW_BIAS_PER_ADDR*BW_PER_PARAM-1:0] conv3_b [0:64-1];
reg [BW_PER_SRAM_GROUP_ADDR-1:0] conv3_pool_ans_b0 [0:16-1], conv3_pool_ans_b1 [0:16-1], conv3_pool_ans_b2 [0:16-1], conv3_pool_ans_b3 [0:16-1];    

// fc 
reg [1024*BW_PER_PARAM-1:0] fc1_w [0:499];
reg [500*BW_PER_PARAM-1:0] fc2_w [0:9];

reg [BW_PER_PARAM-1:0] fc1_b [0:499];
reg [BW_PER_PARAM-1:0] fc2_b [0:9];


// ===== system reset ===== //
initial begin
    clk = 0;
    load_param;
    while(1) #(`CYCLE/2) clk = ~clk;
end



initial begin
	#(`CYCLE * `END_CYCLES);
    $display("\n========================================================");
    $display("   Error!!! Simulation time is too long...            ");
    $display("   There might be something wrong in your code.       ");
	$display("   If your design really needs such a long time,      ");
	$display("   increase the END_CYCLES setting in the testbench.  ");
    $display("========================================================");
    $finish;
end

// ===== cycle counter ===== //
integer cycle_cnt;
integer aver_cycle_cnt;
initial begin
    cycle_cnt = 0;
    aver_cycle_cnt = 0;
    while(1) begin 
        cycle_cnt = cycle_cnt + 1;
        @(negedge clk);
    end
end

// ===== input feeding ===== //
reg [BW_PER_ACT-1:0] mem_img [0:Pattern_N-1];

// ===== output comparision ===== //
integer m;
integer error_bank0, error_bank1,error_bank2, error_bank3;
integer error_total;
integer pat_idx;
integer total_err_pat;

initial begin
	// check if PAT_L and PAT_U are both valid
	if((`PAT_L < 0) || (`PAT_L > `NUM_PAT-1) || (`PAT_U < 0) || (`PAT_U > `NUM_PAT-1)) begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                                             X");
		$display("X   Error!!! PAT_L and PAT_U should be within the range [0, %3d]              X", `NUM_PAT-1);
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

    // show simulation configuration
    if     (test_layer==UNSHUFFLE) $display("\n%c[1;36mStart checking UNSHUFFLE layer ... %c[0m\n", 27, 27);
    else if(test_layer==CONV1_DW)  $display("\n%c[1;36mStart checking CONV1_DW layer ...  %c[0m\n", 27, 27);
    else if(test_layer==CONV1_PW)  $display("\n%c[1;36mStart checking CONV1_PW layer ...  %c[0m\n", 27, 27);
    else if(test_layer==CONV2_DW)  $display("\n%c[1;36mStart checking CONV2_DW layer ...  %c[0m\n", 27, 27);
    else if(test_layer==CONV2_PW)  $display("\n%c[1;36mStart checking CONV2_PW layer ...  %c[0m\n", 27, 27);
    else                           $display("\n%c[1;36mStart checking CONV3_POOL layer ...%c[0m\n", 27, 27);

    total_err_pat = 0;

    for(pat_idx=`PAT_L; pat_idx<=`PAT_U;pat_idx=pat_idx+1)begin
        sram_36x192b_a0.reset_sram;
        sram_36x192b_a1.reset_sram;
        sram_36x192b_a2.reset_sram;
        sram_36x192b_a3.reset_sram;

        sram_18x192b_b0.reset_sram;
        sram_18x192b_b1.reset_sram;
        sram_18x192b_b2.reset_sram;
        sram_18x192b_b3.reset_sram;
        load_golden(pat_idx);

        error_bank0 = 0;
        error_bank1 = 0;
        error_bank2 = 0;
        error_bank3 = 0;
        

        $display("\n================================================================");
        $display("======================== Pattern No. %02d ========================", pat_idx);
        $display("================================================================");

        if(`FLAG_SHOWNUM) bmp2reg(pat_idx);    //load bmp into mem
        if(`FLAG_SHOWNUM) $display("Input image: ");
        if(`FLAG_SHOWNUM) display_reg;
        $display();

        srst_n = 1;
        enable = 0;
        @(negedge clk); srst_n = 1'b0;
        @(negedge clk); srst_n = 1'b1; enable = 1'b1;
        @(negedge clk); enable = 1'b0;
    
        wait(valid);
        @(negedge clk);
        case(test_layer)
            UNSHUFFLE: begin
                for(m=0; m<4; m=m+1) begin
                    if(unshuffle_ans_a0[m] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, UNSHUFFLE, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=4; m<8; m=m+1) begin
                    if(unshuffle_ans_a0[m] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end
                    else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, UNSHUFFLE, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=8; m<12; m=m+1) begin
                    if(unshuffle_ans_a0[m] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, UNSHUFFLE, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=12; m<16; m=m+1) begin
                    if(unshuffle_ans_a0[m] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, UNSHUFFLE, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end

                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank0 == 0) begin
                    if(`FLAG_VERBOSE) $display("Unshuffle results in sram #A0 are successfully passed!");
                end else begin
                    $display("Unshuffle results in sram #A0 have %0d errors!", error_bank0);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(unshuffle_ans_a1[m] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, UNSHUFFLE, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(unshuffle_ans_a1[m-1] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, UNSHUFFLE, m, 1);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=8; m<11; m=m+1) begin
                    if(unshuffle_ans_a1[m-2] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, UNSHUFFLE, m, 2);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=12; m<15; m=m+1) begin
                    if(unshuffle_ans_a1[m-3] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, UNSHUFFLE, m, 3);
                        error_bank1 = error_bank1 + 1;
                    end
                end

                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank1 == 0) begin
                    if(`FLAG_VERBOSE) $display("Unshuffle results in sram #A1 are successfully passed!");
                end else begin
                    $display("Unshuffle results in sram #A1 have %0d errors!", error_bank1);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<4; m=m+1) begin
                    if(unshuffle_ans_a2[m] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, UNSHUFFLE, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=4; m<8; m=m+1) begin
                    if(unshuffle_ans_a2[m] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, UNSHUFFLE, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=8; m<12; m=m+1) begin
                    if(unshuffle_ans_a2[m] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, UNSHUFFLE, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank2 == 0) begin
                    if(`FLAG_VERBOSE) $display("Unshuffle results in sram #A2 are successfully passed!");
                end else begin
                    $display("Unshuffle results in sram #A2 have %0d errors!", error_bank2);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(unshuffle_ans_a3[m] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, UNSHUFFLE, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(unshuffle_ans_a3[m-1] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, UNSHUFFLE, m, 1);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=8; m<11; m=m+1) begin
                    if(unshuffle_ans_a3[m-2] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, UNSHUFFLE, m, 2);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank3 == 0) begin
                    if(`FLAG_VERBOSE) $display("Unshuffle results in sram #A3 are successfully passed!");
                end else begin
                    $display("Unshuffle results in sram #A3 have %0d errors!", error_bank3);
                end
                if(`FLAG_VERBOSE) $display("========================================================");

                error_total = error_bank0 + error_bank1 + error_bank2 + error_bank3; 

                // summary of this pattern
                if(`FLAG_VERBOSE) $display("\n========================================================");
                if(error_total == 0) begin
                    if(`FLAG_VERBOSE) $display("Congratulations! Your UNSHUFFLE layer is correct!");
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is successfully passed !", i);
                    else              $write("%c[1;32mPASS! %c[0m",27, 27);
                end else begin
                    if(`FLAG_VERBOSE) $display("There are total %0d errors in your UNSHUFFLE layer.", error_total);
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is failed...", pat_idx);
                    else              $write("%c[1;31mFAIL! %c[0m",27, 27);
                    total_err_pat = total_err_pat + 1;
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                // $finish;
            end

            CONV1_DW: begin

                for(m=0; m<3; m=m+1) begin
                    if(conv1_dw_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV1_DW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=3; m<6; m=m+1) begin
                    if(conv1_dw_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV1_DW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=6; m<9; m=m+1) begin
                    if(conv1_dw_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV1_DW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank0 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV1_DW results in sram #B0 are successfully passed!");
                end else begin
                    $display("CONV1_DW results in sram #B0 have %0d errors!", error_bank0);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv1_dw_ans_b1[m] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV1_DW, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=3; m<6; m=m+1) begin
                    if(conv1_dw_ans_b1[m] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV1_DW, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=6; m<9; m=m+1) begin
                    if(conv1_dw_ans_b1[m] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV1_DW, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank1 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV1_DW results in sram #B1 are successfully passed!");
                end else begin
                    $display("CONV1_DW results in sram #B1 have %0d errors!", error_bank1);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv1_dw_ans_b2[m] === sram_18x192b_b2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B2, CONV1_DW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=3; m<6; m=m+1) begin
                    if(conv1_dw_ans_b2[m] === sram_18x192b_b2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B2, CONV1_DW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=6; m<9; m=m+1) begin
                    if(conv1_dw_ans_b2[m] === sram_18x192b_b2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B2, CONV1_DW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank2 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV1_DW results in sram #B2 are successfully passed!");
                end else begin
                    $display("CONV1_DW results in sram #B2 have %0d errors!", error_bank2);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv1_dw_ans_b3[m] === sram_18x192b_b3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B3, CONV1_DW, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=3; m<6; m=m+1) begin
                    if(conv1_dw_ans_b3[m] === sram_18x192b_b3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B3, CONV1_DW, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=6; m<9; m=m+1) begin
                    if(conv1_dw_ans_b3[m] === sram_18x192b_b3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B3, CONV1_DW, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank3 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV1_DW results in sram #B3 are successfully passed!");
                end else begin
                    $display("CONV1_DW results in sram #B3 have %0d errors!", error_bank3);
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                error_total = error_bank0 + error_bank1 + error_bank2 + error_bank3; 

                // summary of this pattern    
                if(`FLAG_VERBOSE) $display("\n========================================================");
                if(error_total == 0) begin
                    if(`FLAG_VERBOSE) $display("Congratulations! Your CONV1_DW layer is correct!");
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is successfully passed !", pat_idx);
                    else              $write("%c[1;32mPASS! %c[0m",27, 27);
                end else begin
                    if(`FLAG_VERBOSE) $display("There are total %0d errors in your CONV1_DW layer.", error_total);
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is failed...", pat_idx);
                    else              $write("%c[1;31mFAIL! %c[0m",27, 27);
                    total_err_pat = total_err_pat + 1;
                end
                if(`FLAG_VERBOSE) $display("========================================================");


            end
            CONV1_PW: begin
                for(m=0; m<3; m=m+1) begin
                    if(conv1_pw_ans_a0[m] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV1_PW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(conv1_pw_ans_a0[m-1] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV1_PW, m, 1);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=8; m<11; m=m+1) begin
                    if(conv1_pw_ans_a0[m-2] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV1_PW, m, 2);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank0 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV1_PW results in sram #A0 are successfully passed!");
                end else begin
                    $display("CONV1_PW results in sram #A0 have %0d errors!", error_bank0);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv1_pw_ans_a1[m] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV1_PW, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(conv1_pw_ans_a1[m-1] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV1_PW, m, 1);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=8; m<10; m=m+1) begin
                    if(conv1_pw_ans_a1[m-2] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV1_PW, m, 2);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank1 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV1_PW results in sram #A1 are successfully passed!");
                end else begin
                    $display("CONV1_PW results in sram #A1 have %0d errors!", error_bank1);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv1_pw_ans_a2[m] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV1_PW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(conv1_pw_ans_a2[m-1] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV1_PW, m, 1);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=8; m<11; m=m+1) begin
                    if(conv1_pw_ans_a2[m-2] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV1_PW, m, 2);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                if(`FLAG_VERBOSE)$display("========================================================");
                if(error_bank2 == 0) begin
                    if(`FLAG_VERBOSE)$display("CONV1_PW results in sram #A2 are successfully passed!");
                end else begin
                    $display("CONV1_PW results in sram #A2 have %0d errors!", error_bank2);

                end
                if(`FLAG_VERBOSE)$display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv1_pw_ans_a3[m] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV1_PW, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(conv1_pw_ans_a3[m-1] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV1_PW, m, 1);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=8; m<11; m=m+1) begin
                    if(conv1_pw_ans_a3[m-2] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV1_PW, m, 2);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                if(`FLAG_VERBOSE)$display("========================================================");
                if(error_bank3 == 0) begin
                    if(`FLAG_VERBOSE)$display("CONV1_PW results in sram #A3 are successfully passed!");
                end else begin
                    $display("CONV1_PW results in sram #A3 have %0d errors!", error_bank3);

                end
                if(`FLAG_VERBOSE)$display("========================================================");

                error_total = error_bank0 + error_bank1 + error_bank2 + error_bank3; 

                // summary of this pattern    
                if(`FLAG_VERBOSE) $display("\n========================================================");
                if(error_total == 0) begin
                    if(`FLAG_VERBOSE) $display("Congratulations! Your CONV1_PW layer is correct!");
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is successfully passed !", pat_idx);
                    else              $write("%c[1;32mPASS! %c[0m",27, 27);
                end else begin
                    if(`FLAG_VERBOSE) $display("There are total %0d errors in your CONV1_PW layer.", error_total);
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is failed...", pat_idx);
                    else              $write("%c[1;31mFAIL! %c[0m",27, 27);
                    total_err_pat = total_err_pat + 1;
                end
                if(`FLAG_VERBOSE) $display("========================================================");

            end
            CONV2_DW: begin

                for(m=0; m<3; m=m+1) begin
                    if(conv2_dw_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV2_DW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=3; m<6; m=m+1) begin
                    if(conv2_dw_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV2_DW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=6; m<9; m=m+1) begin
                    if(conv2_dw_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV2_DW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                if(`FLAG_VERBOSE)$display("========================================================");
                if(error_bank0 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV2_DW results in Sram #B0 are successfully passed!");
                end else begin
                    $display("CONV2_DW results in Sram #B0 have %0d errors!", error_bank0);
                end
                if(`FLAG_VERBOSE)$display("========================================================\n");

                for(m=0; m<2; m=m+1) begin
                    if(conv2_dw_ans_b1[m] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV2_DW, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=3; m<5; m=m+1) begin
                    if(conv2_dw_ans_b1[m-1] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV2_DW, m, 1);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=6; m<8; m=m+1) begin
                    if(conv2_dw_ans_b1[m-2] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV2_DW, m, 2);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                if(`FLAG_VERBOSE)$display("========================================================");
                if(error_bank1 == 0) begin
                    if(`FLAG_VERBOSE)$display("CONV2_DW results in Sram #B1 are successfully passed!");
                end else begin
                    $display("CONV2_DW results in Sram #B1 have %0d errors!", error_bank1);
                end
                if(`FLAG_VERBOSE)$display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv2_dw_ans_b2[m] === sram_18x192b_b2.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B2, CONV2_DW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=3; m<6; m=m+1) begin
                    if(conv2_dw_ans_b2[m] === sram_18x192b_b2.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B2, CONV2_DW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end

                if(`FLAG_VERBOSE)$display("========================================================");
                if(error_bank2 == 0) begin
                    if(`FLAG_VERBOSE)$display("CONV2_DW results in Sram #B2 are successfully passed!");
                end else begin
                    $display("CONV2_DW results in Sram #B2 have %0d errors!", error_bank2);
                end
                if(`FLAG_VERBOSE)$display("========================================================\n");

                for(m=0; m<2; m=m+1) begin
                    if(conv2_dw_ans_b3[m] === sram_18x192b_b3.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B3, CONV2_DW, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=3; m<5; m=m+1) begin
                    if(conv2_dw_ans_b3[m-1] === sram_18x192b_b3.mem[m]) begin
                        if(`FLAG_VERBOSE)$display("Sram #B3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B3, CONV2_DW, m, 1);
                        error_bank3 = error_bank3 + 1;
                    end
                end

                if(`FLAG_VERBOSE)$display("========================================================");
                if(error_bank3 == 0) begin
                    if(`FLAG_VERBOSE)$display("CONV2_DW results in Sram #B3 are successfully passed!");
                end else begin
                    $display("CONV2_DW results in Sram #B3 have %0d errors!", error_bank3);
                end
                if(`FLAG_VERBOSE)$display("========================================================");

                error_total = error_bank0 + error_bank1 + error_bank2 + error_bank3; 

                // summary of this pattern    
                if(`FLAG_VERBOSE) $display("\n========================================================");
                if(error_total == 0) begin
                    if(`FLAG_VERBOSE) $display("Congratulations! Your CONV2_DW layer is correct!");
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is successfully passed !", pat_idx);
                    else              $write("%c[1;32mPASS! %c[0m",27, 27);
                end else begin
                    if(`FLAG_VERBOSE) $display("There are total %0d errors in your CONV2_DW layer.", error_total);
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is failed...", pat_idx);
                    else              $write("%c[1;31mFAIL! %c[0m",27, 27);
                    total_err_pat = total_err_pat + 1;
                end
                if(`FLAG_VERBOSE) $display("========================================================");

            end
            CONV2_PW: begin

                for(m=0; m<3; m=m+1) begin
                    if(conv2_pw_ans_a0[m] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(conv2_pw_ans_a0[m-1] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 1);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=8; m<11; m=m+1) begin
                    if(conv2_pw_ans_a0[m-2] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 2);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=12; m<15; m=m+1) begin
                    if(conv2_pw_ans_a0[m-3] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 3);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=16; m<19; m=m+1) begin
                    if(conv2_pw_ans_a0[m-4] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 4);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=20; m<23; m=m+1) begin
                    if(conv2_pw_ans_a0[m-5] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 5);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=24; m<27; m=m+1) begin
                    if(conv2_pw_ans_a0[m-6] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 6);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=28; m<31; m=m+1) begin
                    if(conv2_pw_ans_a0[m-7] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 7);
                        error_bank0 = error_bank0 + 1;
                    end
                end
                for(m=32; m<35; m=m+1) begin
                    if(conv2_pw_ans_a0[m-8] === sram_36x192b_a0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A0, CONV2_PW, m, 8);
                        error_bank0 = error_bank0 + 1;
                    end
                end

                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank0 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV2_PW results in Sram #A0 are successfully passed!");
                end else begin
                    $display("CONV2_PW results in Sram #A0 have %0d errors!", error_bank0);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<2; m=m+1) begin
                    if(conv2_pw_ans_a1[m] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=4; m<6; m=m+1) begin
                    if(conv2_pw_ans_a1[m-2] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 2);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=8; m<10; m=m+1) begin
                    if(conv2_pw_ans_a1[m-4] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 4);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=12; m<14; m=m+1) begin
                    if(conv2_pw_ans_a1[m-6] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 6);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=16; m<18; m=m+1) begin
                    if(conv2_pw_ans_a1[m-8] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 8);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=20; m<22; m=m+1) begin
                    if(conv2_pw_ans_a1[m-10] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 10);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=24; m<26; m=m+1) begin
                    if(conv2_pw_ans_a1[m-12] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 12);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=28; m<30; m=m+1) begin
                    if(conv2_pw_ans_a1[m-14] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 14);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                for(m=32; m<34; m=m+1) begin
                    if(conv2_pw_ans_a1[m-16] === sram_36x192b_a1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A1, CONV2_PW, m, 16);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank1 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV2_PW results in Sram #A1 are successfully passed!");
                end else begin
                    $display("CONV2_PW results in Sram #A1 have %0d errors!", error_bank1);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<3; m=m+1) begin
                    if(conv2_pw_ans_a2[m] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV2_PW, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=4; m<7; m=m+1) begin
                    if(conv2_pw_ans_a2[m-1] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV2_PW, m, 1);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=12; m<15; m=m+1) begin
                    if(conv2_pw_ans_a2[m-6] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV2_PW, m, 6);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=16; m<19; m=m+1) begin
                    if(conv2_pw_ans_a2[m-7] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV2_PW, m, 7);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=24; m<27; m=m+1) begin
                    if(conv2_pw_ans_a2[m-12] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV2_PW, m, 12);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                for(m=28; m<31; m=m+1) begin
                    if(conv2_pw_ans_a2[m-13] === sram_36x192b_a2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A2, CONV2_PW, m, 13);
                        error_bank2 = error_bank2 + 1;
                    end
                end

                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank2 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV2_PW results in Sram #A2 are successfully passed!");
                end else begin
                    $display("CONV2_PW results in Sram #A2 have %0d errors!", error_bank2);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<2; m=m+1) begin
                    if(conv2_pw_ans_a3[m] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV2_PW, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=4; m<6; m=m+1) begin
                    if(conv2_pw_ans_a3[m-2] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV2_PW, m, 2);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=12; m<14; m=m+1) begin
                    if(conv2_pw_ans_a3[m-8] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV2_PW, m, 8);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=16; m<18; m=m+1) begin
                    if(conv2_pw_ans_a3[m-10] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV2_PW, m, 10);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=24; m<26; m=m+1) begin
                    if(conv2_pw_ans_a3[m-16] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV2_PW, m, 16);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                for(m=28; m<30; m=m+1) begin
                    if(conv2_pw_ans_a3[m-18] === sram_36x192b_a3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #A3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(A3, CONV2_PW, m, 18);
                        error_bank3 = error_bank3 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank3 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV2_PW results in Sram #A3 are successfully passed!");
                end else begin
                    $display("CONV2_PW results in Sram #A3 have %0d errors!", error_bank3);
                end
                if(`FLAG_VERBOSE) $display("========================================================");

                error_total = error_bank0 + error_bank1 + error_bank2 + error_bank3; 


                // summary of this pattern    
                if(`FLAG_VERBOSE) $display("\n========================================================");
                if(error_total == 0) begin
                    if(`FLAG_VERBOSE) $display("Congratulations! Your CONV2_PW layer is correct!");
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is successfully passed !", pat_idx);
                    else              $write("%c[1;32mPASS! %c[0m",27, 27);
                end else begin
                    if(`FLAG_VERBOSE) $display("There are total %0d errors in your CONV2_PW layer.", error_total);
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is failed...", pat_idx);
                    else              $write("%c[1;31mFAIL! %c[0m",27, 27);
                    total_err_pat = total_err_pat + 1;
                end
                if(`FLAG_VERBOSE) $display("========================================================");

            end
            CONV3_POOL: begin

                for(m=0; m<16; m=m+1) begin
                    if(conv3_pool_ans_b0[m] === sram_18x192b_b0.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B0 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B0, CONV3_POOL, m, 0);
                        error_bank0 = error_bank0 + 1;
                    end
                end

                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank0 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV3_POOL results in Sram #B0 are successfully passed!");
                end else begin
                    $display("CONV3_POOL results in Sram #B0 have %0d errors!", error_bank0);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");
                for(m=0; m<16; m=m+1) begin
                    if(conv3_pool_ans_b1[m] === sram_18x192b_b1.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B1 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B1, CONV3_POOL, m, 0);
                        error_bank1 = error_bank1 + 1;
                    end
                end
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank1 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV3_POOL results in Sram #B1 are successfully passed!");
                end else begin
                    $display("CONV3_POOL results in Sram #B1 have %0d errors!", error_bank1);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");

                for(m=0; m<16; m=m+1) begin
                    if(conv3_pool_ans_b2[m] === sram_18x192b_b2.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B2 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B2, CONV3_POOL, m, 0);
                        error_bank2 = error_bank2 + 1;
                    end
                end
                
                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank2 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV3_POOL results in Sram #B2 are successfully passed!");
                end else begin
                    $display("CONV3_POOL results in Sram #B2 have %0d errors!", error_bank2);
                end
                if(`FLAG_VERBOSE) $display("========================================================\n");
                for(m=0; m<16; m=m+1) begin
                    if(conv3_pool_ans_b3[m] === sram_18x192b_b3.mem[m]) begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d PASS!", m);
                    end else begin
                        if(`FLAG_VERBOSE) $display("Sram #B3 address %0d FAIL!", m);
                        if(`FLAG_VERBOSE) display_error(B3, CONV3_POOL, m, 0);
                        error_bank3 = error_bank3 + 1;
                    end
                end

                if(`FLAG_VERBOSE) $display("========================================================");
                if(error_bank3 == 0) begin
                    if(`FLAG_VERBOSE) $display("CONV3_POOL results in Sram #B3 are successfully passed!");
                end else begin
                    $display("CONV3_POOL results in Sram #B3 have %0d errors!", error_bank3);
                end
                if(`FLAG_VERBOSE) $display("========================================================");

                error_total = error_bank0 + error_bank1 + error_bank2 + error_bank3; 


                // summary of this pattern    
                if(`FLAG_VERBOSE) $display("\n========================================================");
                if(error_total == 0) begin
                    if(`FLAG_VERBOSE) begin
                        $display("Congratulations! Your CONV3_POOL layer is correct!");
                        $display("Pattern No. %02d is successfully passed !", pat_idx);
                    end 
                    else      $write("%c[1;32mPASS! %c[0m",27, 27);

                    if(`FLAG_SHOWNUM) begin
                        $display("\nFollowing shows the output of FC2 and recongnition result:");
                        FLAT_layer;
                        FC1_layer;
                        FC2_layer;
                    end

                end else begin
                    if(`FLAG_VERBOSE) $display("There are total %0d errors in your CONV3_POOL layer.", error_total);
                    if(`FLAG_VERBOSE) $display("Pattern No. %02d is failed...", pat_idx);
                    else              $write("%c[1;31mFAIL! %c[0m",27, 27);
                    total_err_pat = total_err_pat + 1;
                end
                if(`FLAG_VERBOSE) $display("========================================================");


            end
        endcase

    end

    aver_cycle_cnt = cycle_cnt/`NUM_PAT;
    // summary of all pattern
    $display("\n\n\n             Summary of all pattern: ");
    if(total_err_pat == 0) begin 
        $display("-----------------------------------------------------\n");
        $write("%c[1;32mCongratulations! %c[0m",27, 27);
        case(test_layer)
            UNSHUFFLE:  $display("Your UNSHUFFLE layer is correct!");
            CONV1_DW:   $display("Your CONV1_DW layer is correct!");
            CONV1_PW:   $display("Your CONV1_PW layer is correct!");
            CONV2_DW:   $display("Your CONV2_DW layer is correct!");
            CONV2_PW:   $display("Your CONV2_PW layer is correct!");
            CONV3_POOL: $display("Your CONV3_POOL layer is correct!");  
        endcase
        // $write("",27);
        $display("Total cycle count = %0d", cycle_cnt);
        $display("Average cycle count per pattern = %0d", aver_cycle_cnt);
        $display("-------------------------PASS------------------------\n");
        
    end else begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                 X");

        case(test_layer)
            UNSHUFFLE:  $display("X   Error!!! Your Your UNSHUFFLE  layer is wrong! X");
            CONV1_DW:   $display("X   Error!!! Your Your CONV1_DW   layer is wrong! X");
            CONV1_PW:   $display("X   Error!!! Your Your CONV1_PW   layer is wrong! X");
            CONV2_DW:   $display("X   Error!!! Your Your CONV2_DW   layer is wrong! X");
            CONV2_PW:   $display("X   Error!!! Your Your CONV2_PW   layer is wrong! X");
            CONV3_POOL: $display("X   Error!!! Your Your CONV3_POOL layer is wrong! X");  
        endcase

        $display("X         %3d patterns are failed... (T ~ T)      X", total_err_pat);
		$display("X                                                 X");
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
        $display("Total cycle count = %0d", cycle_cnt);
        $display("Average cycle count per pattern = %0d", aver_cycle_cnt);
          
    end

	// check if all patterns are simulated
	if((`PAT_L != 0) || (`PAT_U != `NUM_PAT-1)) begin
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$display("X                                                                                                           X");
		$display("X   Warning!!! You only simulate Pattern No. %3d to No. %3d                                                 X", `PAT_L, `PAT_U);
		$display("X   There are total %3d patterns.                                                                           X", `NUM_PAT);
		$display("X   Remember to simulate all patterns and check if all are passed.                                          X");
		$display("X   The average cycle count C per pattern in the PI should be the result when all patterns are simulated.   X");
		$display("X                                                                                                           X");
		$display("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		$write("\n");
	end


    $finish;

end

task bmp2reg(
input integer pat_no
);

    reg [20*8-1:0] bmp_filename;
    integer this_i, this_j, i, j;
    integer file_in;
    reg [7:0] char_in;

    begin
        bmp_filename = "../bmp/test_0000.bmp";
        bmp_filename[8*8-1:7*8] = (pat_no/1000)+48;
        bmp_filename[7*8-1:6*8] = (pat_no%1000)/100+48;
        bmp_filename[6*8-1:5*8] = (pat_no%100)/10+48;
        bmp_filename[5*8-1:4*8] = pat_no%10+48;

        file_in = $fopen(bmp_filename, "rb");

        // skip the header
        for(this_i=0; this_i<1078; this_i=this_i+1)
           char_in = $fgetc(file_in);

        for(this_i=27; this_i>=0; this_i=this_i-1) begin
            for(this_j=0; this_j<28; this_j=this_j+1) begin //four-byte alignment
                char_in = $fgetc(file_in);
                if(char_in <= 127)  
                    mem_img[this_i*28 + this_j] = char_in;
                else 
                    mem_img[this_i*28 + this_j] = 127;
            end
        end
    end
endtask

task display_reg;
    
    integer this_i, this_j;

    begin
        for(this_i=0; this_i<28; this_i=this_i+1) begin
            for(this_j=0; this_j<28; this_j=this_j+1) begin
               $write("%d", mem_img[this_i*28 + this_j]);
            end
            $write("\n");
        end
    end

endtask


integer j, k, l;
reg signed [BW_PER_ACT-1:0] flatten_out [0:1023];

task FLAT_layer;
    begin
        l = 0;

        for(j=0; j<16; j=j+1) begin
            for(k=0; k<4; k=k+1) begin
                flatten_out[l + 0]  = sram_18x192b_b0.mem[j][48*(3-k)+36 +: 12];           
                flatten_out[l + 1]  = sram_18x192b_b0.mem[j][48*(3-k)+24 +: 12];
                flatten_out[l + 2]  = sram_18x192b_b1.mem[j][48*(3-k)+36 +: 12];
                flatten_out[l + 3]  = sram_18x192b_b1.mem[j][48*(3-k)+24 +: 12];
                flatten_out[l + 4]  = sram_18x192b_b0.mem[j][48*(3-k)+12 +: 12];
                flatten_out[l + 5]  = sram_18x192b_b0.mem[j][48*(3-k)+0 +: 12];
                flatten_out[l + 6]  = sram_18x192b_b1.mem[j][48*(3-k)+12 +: 12];
                flatten_out[l + 7]  = sram_18x192b_b1.mem[j][48*(3-k)+0 +: 12];
                flatten_out[l + 8]  = sram_18x192b_b2.mem[j][48*(3-k)+36 +: 12];
                flatten_out[l + 9]  = sram_18x192b_b2.mem[j][48*(3-k)+24 +: 12];               
                flatten_out[l + 10] = sram_18x192b_b3.mem[j][48*(3-k)+36 +: 12];
                flatten_out[l + 11] = sram_18x192b_b3.mem[j][48*(3-k)+24 +: 12];
                flatten_out[l + 12] = sram_18x192b_b2.mem[j][48*(3-k)+12 +: 12];
                flatten_out[l + 13] = sram_18x192b_b2.mem[j][48*(3-k)+0 +: 12];
                flatten_out[l + 14] = sram_18x192b_b3.mem[j][48*(3-k)+12 +: 12];
                flatten_out[l + 15] = sram_18x192b_b3.mem[j][48*(3-k)+0 +: 12];
                l = l+16;
            end
        end   

    end
endtask


reg signed [BW_PER_ACT-1:0] fc1_out [0:499];
reg signed [31:0] tmp_sum;

task FC1_layer;
    begin
        for(k=0; k<500; k=k+1) begin
            tmp_sum = 0;
            for(j=0; j<1024; j=j+1) begin
                tmp_sum = tmp_sum + $signed(flatten_out[j]) * $signed(fc1_w[k][(1023-j)*8 +: 8]);
            end
            tmp_sum = tmp_sum + ($signed(fc1_b[k]) << 8);
            tmp_sum = tmp_sum + (1 << 6);
            tmp_sum = tmp_sum >>> 7;

            if(tmp_sum >= 2047) 
                fc1_out[k] = 2047;
            else if(tmp_sum < 0) 
                fc1_out[k] = 0;
            else 
                fc1_out[k] = tmp_sum[11:0];
        end
    end
endtask

reg signed [BW_PER_ACT-1:0] fc2_out [0:9];
reg signed [BW_PER_ACT-1:0] tmp_big;
reg [BW_PER_ACT-1:0] ans;

task FC2_layer;
    begin
        for(k=0; k<10; k=k+1) begin
            tmp_sum = 0;
            for(j=0; j<500; j=j+1) begin
                tmp_sum = tmp_sum + $signed(fc1_out[j]) * $signed(fc2_w[k][(499-j)*8 +: 8]);
            end
            tmp_sum = tmp_sum + ($signed(fc2_b[k]) << 8);
            tmp_sum = tmp_sum + (1 << 6);
            tmp_sum = tmp_sum >>> 7;

            if(tmp_sum >= 2047) 
                fc2_out[k] = 2047;
            else if(tmp_sum < -2048) 
                fc2_out[k] = -2048;
            else 
                fc2_out[k] = tmp_sum[11:0];
        end

        $write("Output of FC2: ");
        tmp_big = fc2_out[0];
        ans = 0;
        for(k=0; k<10; k=k+1) begin
            $write("%0d ", fc2_out[k]);
            if(fc2_out[k] > tmp_big) begin
                tmp_big = fc2_out[k];
                ans = k;
            end
        end
        $write("\nRecognition result: %0d\n", ans);
    end
endtask


task load_param;
    begin
        // conv1 dw 
        $readmemb("param/conv1_dw_weight.dat", conv1_dw_w);
        $readmemb("param/conv1_dw_bias.dat", conv1_dw_b);
        // conv1 pw
        $readmemb("param/conv1_pw_weight.dat", conv1_pw_w);
        $readmemb("param/conv1_pw_bias.dat", conv1_pw_b);
        // conv2 dw
        $readmemb("param/conv2_dw_weight.dat", conv2_dw_w);
        $readmemb("param/conv2_dw_bias.dat", conv2_dw_b);
        // conv2 pw
        $readmemb("param/conv2_pw_weight.dat", conv2_pw_w);
        $readmemb("param/conv2_pw_bias.dat", conv2_pw_b);
        // conv3
        $readmemb("param/conv3_weight.dat", conv3_w);
        $readmemb("param/conv3_bias.dat", conv3_b);

        // store weights into sram
        for(i=0; i<4; i=i+1) begin
            sram_784x72b_weight.load_param(i, conv1_dw_w[i]);
        end
        for(i=4; i<6;i=i+1) begin
            sram_784x72b_weight.load_param(i, conv1_pw_w[i-4]);
        end
        for(i=6; i<10;i=i+1) begin
            sram_784x72b_weight.load_param(i, conv2_dw_w[i-6]);
        end
        for(i=10; i<16;i=i+1) begin
            sram_784x72b_weight.load_param(i, conv2_pw_w[i-10]);
        end
        for(i=16; i<784;i=i+1) begin
            sram_784x72b_weight.load_param(i, conv3_w[i-16]);
        end
        // store biases into sram
        for(i=0; i<4; i=i+1) begin
            sram_88x8b_bias.load_param(i, conv1_dw_b[i]);
        end
        for(i=4; i<8;i=i+1)begin
            sram_88x8b_bias.load_param(i, conv1_pw_b[i-4]);
        end
        for(i=8; i<12;i=i+1)begin
            sram_88x8b_bias.load_param(i, conv2_dw_b[i-8]);
        end
        for(i=12; i<24;i=i+1)begin
            sram_88x8b_bias.load_param(i, conv2_pw_b[i-12]);
        end
        for(i=24; i<88;i=i+1)begin
            sram_88x8b_bias.load_param(i, conv3_b[i-24]);
        end
        // fc
        $readmemb("param/fc1_weight.dat", fc1_w);
        $readmemb("param/fc1_bias.dat", fc1_b);
        $readmemb("param/fc2_weight.dat", fc2_w);
        $readmemb("param/fc2_bias.dat", fc2_b);

    end
endtask


task load_golden(
    input integer index
);
    reg [8-1:0] index_digit_3, index_digit_2, index_digit_1, index_digit_0;
    begin
        unshuffle_a0_golden_file = "golden/0000_unshuffle_a0.dat";
        unshuffle_a1_golden_file = "golden/0000_unshuffle_a1.dat";
        unshuffle_a2_golden_file = "golden/0000_unshuffle_a2.dat";
        unshuffle_a3_golden_file = "golden/0000_unshuffle_a3.dat";
        conv1_dw_b0_golden_file = "golden/0000_conv1_dw_b0.dat";
        conv1_dw_b1_golden_file = "golden/0000_conv1_dw_b1.dat";
        conv1_dw_b2_golden_file = "golden/0000_conv1_dw_b2.dat";
        conv1_dw_b3_golden_file = "golden/0000_conv1_dw_b3.dat";
        conv1_pw_a0_golden_file = "golden/0000_conv1_pw_a0.dat";
        conv1_pw_a1_golden_file = "golden/0000_conv1_pw_a1.dat";
        conv1_pw_a2_golden_file = "golden/0000_conv1_pw_a2.dat";
        conv1_pw_a3_golden_file = "golden/0000_conv1_pw_a3.dat";
        conv2_dw_b0_golden_file = "golden/0000_conv2_dw_b0.dat";
        conv2_dw_b1_golden_file = "golden/0000_conv2_dw_b1.dat";
        conv2_dw_b2_golden_file = "golden/0000_conv2_dw_b2.dat";
        conv2_dw_b3_golden_file = "golden/0000_conv2_dw_b3.dat";
        conv2_pw_a0_golden_file = "golden/0000_conv2_pw_a0.dat";
        conv2_pw_a1_golden_file = "golden/0000_conv2_pw_a1.dat";
        conv2_pw_a2_golden_file = "golden/0000_conv2_pw_a2.dat";
        conv2_pw_a3_golden_file = "golden/0000_conv2_pw_a3.dat";
        conv3_pool_b0_golden_file = "golden/0000_conv3_pool_b0.dat";
        conv3_pool_b1_golden_file = "golden/0000_conv3_pool_b1.dat";
        conv3_pool_b2_golden_file = "golden/0000_conv3_pool_b2.dat";
        conv3_pool_b3_golden_file = "golden/0000_conv3_pool_b3.dat";

        index_digit_3 = (index/1000)+48;
        index_digit_2 = (index%1000)/100+48;
        index_digit_1 = (index%100)/10+48;
        index_digit_0 = (index%10)+48;

        unshuffle_a0_golden_file[17*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        unshuffle_a1_golden_file[17*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        unshuffle_a2_golden_file[17*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        unshuffle_a3_golden_file[17*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
       
        conv1_dw_b0_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv1_dw_b1_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv1_dw_b2_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv1_dw_b3_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        
        conv1_pw_a0_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv1_pw_a1_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv1_pw_a2_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv1_pw_a3_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        
        conv2_dw_b0_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv2_dw_b1_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv2_dw_b2_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv2_dw_b3_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        
        conv2_pw_a0_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv2_pw_a1_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv2_pw_a2_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv2_pw_a3_golden_file[16*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};

        conv3_pool_b0_golden_file[18*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv3_pool_b1_golden_file[18*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv3_pool_b2_golden_file[18*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        conv3_pool_b3_golden_file[18*8+:`PAT_NAME_LENGTH*8] = {index_digit_3, index_digit_2, index_digit_1, index_digit_0};
        
        // unshuffle (save in sram a)
        $readmemb(unshuffle_a0_golden_file, unshuffle_ans_a0);
        $readmemb(unshuffle_a1_golden_file, unshuffle_ans_a1);
        $readmemb(unshuffle_a2_golden_file, unshuffle_ans_a2);
        $readmemb(unshuffle_a3_golden_file, unshuffle_ans_a3);
        // conv1 dw (save in sram b)
        $readmemb(conv1_dw_b0_golden_file, conv1_dw_ans_b0);
        $readmemb(conv1_dw_b1_golden_file, conv1_dw_ans_b1);
        $readmemb(conv1_dw_b2_golden_file, conv1_dw_ans_b2);
        $readmemb(conv1_dw_b3_golden_file, conv1_dw_ans_b3);
        // conv1 pw (save in sram a)
        $readmemb(conv1_pw_a0_golden_file, conv1_pw_ans_a0);
        $readmemb(conv1_pw_a1_golden_file, conv1_pw_ans_a1);
        $readmemb(conv1_pw_a2_golden_file, conv1_pw_ans_a2);
        $readmemb(conv1_pw_a3_golden_file, conv1_pw_ans_a3);
        // conv2 dw (save in sram b)
        $readmemb(conv2_dw_b0_golden_file, conv2_dw_ans_b0);
        $readmemb(conv2_dw_b1_golden_file, conv2_dw_ans_b1);
        $readmemb(conv2_dw_b2_golden_file, conv2_dw_ans_b2);
        $readmemb(conv2_dw_b3_golden_file, conv2_dw_ans_b3);
        // conv2 pw (save in sram a)
        $readmemb(conv2_pw_a0_golden_file, conv2_pw_ans_a0);
        $readmemb(conv2_pw_a1_golden_file, conv2_pw_ans_a1);
        $readmemb(conv2_pw_a2_golden_file, conv2_pw_ans_a2);
        $readmemb(conv2_pw_a3_golden_file, conv2_pw_ans_a3);
        // conv3 (save in sram b)
        $readmemb(conv3_pool_b0_golden_file, conv3_pool_ans_b0);
        $readmemb(conv3_pool_b1_golden_file, conv3_pool_ans_b1);
        $readmemb(conv3_pool_b2_golden_file, conv3_pool_ans_b2);
        $readmemb(conv3_pool_b3_golden_file, conv3_pool_ans_b3);

        // store unshuffled image into sram A
        // a0
        for(i=0; i<16 ;i=i+1)begin
            sram_36x192b_a0.load_act(i, unshuffle_ans_a0[i]);
        end
        // a1
        for(i=0; i<3 ;i=i+1)begin
            sram_36x192b_a1.load_act(i, unshuffle_ans_a1[i]);
        end
        for(i=4; i<7 ;i=i+1)begin
            sram_36x192b_a1.load_act(i, unshuffle_ans_a1[i-1]);
        end
        for(i=8; i<11 ;i=i+1)begin
            sram_36x192b_a1.load_act(i, unshuffle_ans_a1[i-2]);
        end
        for(i=12; i<15 ;i=i+1)begin
            sram_36x192b_a1.load_act(i, unshuffle_ans_a1[i-3]);
        end
        // a2
        for(i=0; i<12 ;i=i+1)begin
            sram_36x192b_a2.load_act(i, unshuffle_ans_a2[i]);
        end
        // a3
        for(i=0; i<3 ;i=i+1)begin
            sram_36x192b_a3.load_act(i, unshuffle_ans_a3[i]);
        end
        for(i=4; i<7 ;i=i+1)begin
            sram_36x192b_a3.load_act(i, unshuffle_ans_a3[i-1]);
        end
        for(i=8; i<11 ;i=i+1)begin
            sram_36x192b_a3.load_act(i, unshuffle_ans_a3[i-2]);
        end

        //           testbench function test !!!              //
        // ================================================== //
        // store final reuslt into sram B
        // for(i=0;i<16;i=i+1)begin
        //     sram_18x192b_b0.load_act(i, conv3_pool_ans_b0[i]);
        //     sram_18x192b_b1.load_act(i, conv3_pool_ans_b1[i]);
        //     sram_18x192b_b2.load_act(i, conv3_pool_ans_b2[i]);
        //     sram_18x192b_b3.load_act(i, conv3_pool_ans_b3[i]);
        // end
        // ================================================== //

    end
endtask



task display_error(
input [2:0] which_sram,
input [2:0] layer,
input integer addr,
input integer ans_offset
);
    begin
        case(which_sram)
            A0: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_36x192b_a0.mem[addr][191:180]), $signed(sram_36x192b_a0.mem[addr][179:168]),
                    $signed(sram_36x192b_a0.mem[addr][167:156]), $signed(sram_36x192b_a0.mem[addr][155:144]), 
                    $signed(sram_36x192b_a0.mem[addr][143:132]), $signed(sram_36x192b_a0.mem[addr][131:120]),
                    $signed(sram_36x192b_a0.mem[addr][119:108]), $signed(sram_36x192b_a0.mem[addr][107:96]),
                    $signed(sram_36x192b_a0.mem[addr][95:84]),   $signed(sram_36x192b_a0.mem[addr][83:72]),
                    $signed(sram_36x192b_a0.mem[addr][71:60]),   $signed(sram_36x192b_a0.mem[addr][59:48]),
                    $signed(sram_36x192b_a0.mem[addr][47:36]),   $signed(sram_36x192b_a0.mem[addr][35:24]),
                    $signed(sram_36x192b_a0.mem[addr][23:12]),   $signed(sram_36x192b_a0.mem[addr][11:0]));
                if(layer == UNSHUFFLE) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(unshuffle_ans_a0[addr-ans_offset][191:180]), $signed(unshuffle_ans_a0[addr-ans_offset][179:168]),
                        $signed(unshuffle_ans_a0[addr-ans_offset][167:156]), $signed(unshuffle_ans_a0[addr-ans_offset][155:144]), 
                        $signed(unshuffle_ans_a0[addr-ans_offset][143:132]), $signed(unshuffle_ans_a0[addr-ans_offset][131:120]),
                        $signed(unshuffle_ans_a0[addr-ans_offset][119:108]), $signed(unshuffle_ans_a0[addr-ans_offset][107:96]),
                        $signed(unshuffle_ans_a0[addr-ans_offset][95:84]),   $signed(unshuffle_ans_a0[addr-ans_offset][83:72]),
                        $signed(unshuffle_ans_a0[addr-ans_offset][71:60]),   $signed(unshuffle_ans_a0[addr-ans_offset][59:48]),
                        $signed(unshuffle_ans_a0[addr-ans_offset][47:36]),   $signed(unshuffle_ans_a0[addr-ans_offset][35:24]),
                        $signed(unshuffle_ans_a0[addr-ans_offset][23:12]),   $signed(unshuffle_ans_a0[addr-ans_offset][11:0]));
                end else if(layer == CONV1_PW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_pw_ans_a0[addr-ans_offset][191:180]), $signed(conv1_pw_ans_a0[addr-ans_offset][179:168]),
                        $signed(conv1_pw_ans_a0[addr-ans_offset][167:156]), $signed(conv1_pw_ans_a0[addr-ans_offset][155:144]), 
                        $signed(conv1_pw_ans_a0[addr-ans_offset][143:132]), $signed(conv1_pw_ans_a0[addr-ans_offset][131:120]),
                        $signed(conv1_pw_ans_a0[addr-ans_offset][119:108]), $signed(conv1_pw_ans_a0[addr-ans_offset][107:96]),
                        $signed(conv1_pw_ans_a0[addr-ans_offset][95:84]),   $signed(conv1_pw_ans_a0[addr-ans_offset][83:72]),
                        $signed(conv1_pw_ans_a0[addr-ans_offset][71:60]),   $signed(conv1_pw_ans_a0[addr-ans_offset][59:48]),
                        $signed(conv1_pw_ans_a0[addr-ans_offset][47:36]),   $signed(conv1_pw_ans_a0[addr-ans_offset][35:24]),
                        $signed(conv1_pw_ans_a0[addr-ans_offset][23:12]),   $signed(conv1_pw_ans_a0[addr-ans_offset][11:0]));
                end else if(layer == CONV2_PW)begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_pw_ans_a0[addr-ans_offset][191:180]), $signed(conv2_pw_ans_a0[addr-ans_offset][179:168]),
                        $signed(conv2_pw_ans_a0[addr-ans_offset][167:156]), $signed(conv2_pw_ans_a0[addr-ans_offset][155:144]), 
                        $signed(conv2_pw_ans_a0[addr-ans_offset][143:132]), $signed(conv2_pw_ans_a0[addr-ans_offset][131:120]),
                        $signed(conv2_pw_ans_a0[addr-ans_offset][119:108]), $signed(conv2_pw_ans_a0[addr-ans_offset][107:96]),
                        $signed(conv2_pw_ans_a0[addr-ans_offset][95:84]),   $signed(conv2_pw_ans_a0[addr-ans_offset][83:72]),
                        $signed(conv2_pw_ans_a0[addr-ans_offset][71:60]),   $signed(conv2_pw_ans_a0[addr-ans_offset][59:48]),
                        $signed(conv2_pw_ans_a0[addr-ans_offset][47:36]),   $signed(conv2_pw_ans_a0[addr-ans_offset][35:24]),
                        $signed(conv2_pw_ans_a0[addr-ans_offset][23:12]),   $signed(conv2_pw_ans_a0[addr-ans_offset][11:0]));
                end
            end
            A1: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_36x192b_a1.mem[addr][191:180]), $signed(sram_36x192b_a1.mem[addr][179:168]),
                    $signed(sram_36x192b_a1.mem[addr][167:156]), $signed(sram_36x192b_a1.mem[addr][155:144]), 
                    $signed(sram_36x192b_a1.mem[addr][143:132]), $signed(sram_36x192b_a1.mem[addr][131:120]),
                    $signed(sram_36x192b_a1.mem[addr][119:108]), $signed(sram_36x192b_a1.mem[addr][107:96]),
                    $signed(sram_36x192b_a1.mem[addr][95:84]),   $signed(sram_36x192b_a1.mem[addr][83:72]),
                    $signed(sram_36x192b_a1.mem[addr][71:60]),   $signed(sram_36x192b_a1.mem[addr][59:48]),
                    $signed(sram_36x192b_a1.mem[addr][47:36]),   $signed(sram_36x192b_a1.mem[addr][35:24]),
                    $signed(sram_36x192b_a1.mem[addr][23:12]),   $signed(sram_36x192b_a1.mem[addr][11:0]));
                if(layer == UNSHUFFLE) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(unshuffle_ans_a1[addr-ans_offset][191:180]), $signed(unshuffle_ans_a1[addr-ans_offset][179:168]),
                        $signed(unshuffle_ans_a1[addr-ans_offset][167:156]), $signed(unshuffle_ans_a1[addr-ans_offset][155:144]), 
                        $signed(unshuffle_ans_a1[addr-ans_offset][143:132]), $signed(unshuffle_ans_a1[addr-ans_offset][131:120]),
                        $signed(unshuffle_ans_a1[addr-ans_offset][119:108]), $signed(unshuffle_ans_a1[addr-ans_offset][107:96]),
                        $signed(unshuffle_ans_a1[addr-ans_offset][95:84]),   $signed(unshuffle_ans_a1[addr-ans_offset][83:72]),
                        $signed(unshuffle_ans_a1[addr-ans_offset][71:60]),   $signed(unshuffle_ans_a1[addr-ans_offset][59:48]),
                        $signed(unshuffle_ans_a1[addr-ans_offset][47:36]),   $signed(unshuffle_ans_a1[addr-ans_offset][35:24]),
                        $signed(unshuffle_ans_a1[addr-ans_offset][23:12]),   $signed(unshuffle_ans_a1[addr-ans_offset][11:0]));
                end else if(layer == CONV1_PW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_pw_ans_a1[addr-ans_offset][191:180]), $signed(conv1_pw_ans_a1[addr-ans_offset][179:168]),
                        $signed(conv1_pw_ans_a1[addr-ans_offset][167:156]), $signed(conv1_pw_ans_a1[addr-ans_offset][155:144]), 
                        $signed(conv1_pw_ans_a1[addr-ans_offset][143:132]), $signed(conv1_pw_ans_a1[addr-ans_offset][131:120]),
                        $signed(conv1_pw_ans_a1[addr-ans_offset][119:108]), $signed(conv1_pw_ans_a1[addr-ans_offset][107:96]),
                        $signed(conv1_pw_ans_a1[addr-ans_offset][95:84]),   $signed(conv1_pw_ans_a1[addr-ans_offset][83:72]),
                        $signed(conv1_pw_ans_a1[addr-ans_offset][71:60]),   $signed(conv1_pw_ans_a1[addr-ans_offset][59:48]),
                        $signed(conv1_pw_ans_a1[addr-ans_offset][47:36]),   $signed(conv1_pw_ans_a1[addr-ans_offset][35:24]),
                        $signed(conv1_pw_ans_a1[addr-ans_offset][23:12]),   $signed(conv1_pw_ans_a1[addr-ans_offset][11:0]));
                end else if(layer == CONV2_PW)begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_pw_ans_a1[addr-ans_offset][191:180]), $signed(conv2_pw_ans_a1[addr-ans_offset][179:168]),
                        $signed(conv2_pw_ans_a1[addr-ans_offset][167:156]), $signed(conv2_pw_ans_a1[addr-ans_offset][155:144]), 
                        $signed(conv2_pw_ans_a1[addr-ans_offset][143:132]), $signed(conv2_pw_ans_a1[addr-ans_offset][131:120]),
                        $signed(conv2_pw_ans_a1[addr-ans_offset][119:108]), $signed(conv2_pw_ans_a1[addr-ans_offset][107:96]),
                        $signed(conv2_pw_ans_a1[addr-ans_offset][95:84]),   $signed(conv2_pw_ans_a1[addr-ans_offset][83:72]),
                        $signed(conv2_pw_ans_a1[addr-ans_offset][71:60]),   $signed(conv2_pw_ans_a1[addr-ans_offset][59:48]),
                        $signed(conv2_pw_ans_a1[addr-ans_offset][47:36]),   $signed(conv2_pw_ans_a1[addr-ans_offset][35:24]),
                        $signed(conv2_pw_ans_a1[addr-ans_offset][23:12]),   $signed(conv2_pw_ans_a1[addr-ans_offset][11:0]));
                end
            end
            A2: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_36x192b_a2.mem[addr][191:180]), $signed(sram_36x192b_a2.mem[addr][179:168]),
                    $signed(sram_36x192b_a2.mem[addr][167:156]), $signed(sram_36x192b_a2.mem[addr][155:144]), 
                    $signed(sram_36x192b_a2.mem[addr][143:132]), $signed(sram_36x192b_a2.mem[addr][131:120]),
                    $signed(sram_36x192b_a2.mem[addr][119:108]), $signed(sram_36x192b_a2.mem[addr][107:96]),
                    $signed(sram_36x192b_a2.mem[addr][95:84]),   $signed(sram_36x192b_a2.mem[addr][83:72]),
                    $signed(sram_36x192b_a2.mem[addr][71:60]),   $signed(sram_36x192b_a2.mem[addr][59:48]),
                    $signed(sram_36x192b_a2.mem[addr][47:36]),   $signed(sram_36x192b_a2.mem[addr][35:24]),
                    $signed(sram_36x192b_a2.mem[addr][23:12]),   $signed(sram_36x192b_a2.mem[addr][11:0]));
                if(layer == UNSHUFFLE) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(unshuffle_ans_a2[addr-ans_offset][191:180]), $signed(unshuffle_ans_a2[addr-ans_offset][179:168]),
                        $signed(unshuffle_ans_a2[addr-ans_offset][167:156]), $signed(unshuffle_ans_a2[addr-ans_offset][155:144]), 
                        $signed(unshuffle_ans_a2[addr-ans_offset][143:132]), $signed(unshuffle_ans_a2[addr-ans_offset][131:120]),
                        $signed(unshuffle_ans_a2[addr-ans_offset][119:108]), $signed(unshuffle_ans_a2[addr-ans_offset][107:96]),
                        $signed(unshuffle_ans_a2[addr-ans_offset][95:84]),   $signed(unshuffle_ans_a2[addr-ans_offset][83:72]),
                        $signed(unshuffle_ans_a2[addr-ans_offset][71:60]),   $signed(unshuffle_ans_a2[addr-ans_offset][59:48]),
                        $signed(unshuffle_ans_a2[addr-ans_offset][47:36]),   $signed(unshuffle_ans_a2[addr-ans_offset][35:24]),
                        $signed(unshuffle_ans_a2[addr-ans_offset][23:12]),   $signed(unshuffle_ans_a2[addr-ans_offset][11:0]));
                end else if(layer == CONV1_PW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_pw_ans_a2[addr-ans_offset][191:180]), $signed(conv1_pw_ans_a2[addr-ans_offset][179:168]),
                        $signed(conv1_pw_ans_a2[addr-ans_offset][167:156]), $signed(conv1_pw_ans_a2[addr-ans_offset][155:144]), 
                        $signed(conv1_pw_ans_a2[addr-ans_offset][143:132]), $signed(conv1_pw_ans_a2[addr-ans_offset][131:120]),
                        $signed(conv1_pw_ans_a2[addr-ans_offset][119:108]), $signed(conv1_pw_ans_a2[addr-ans_offset][107:96]),
                        $signed(conv1_pw_ans_a2[addr-ans_offset][95:84]),   $signed(conv1_pw_ans_a2[addr-ans_offset][83:72]),
                        $signed(conv1_pw_ans_a2[addr-ans_offset][71:60]),   $signed(conv1_pw_ans_a2[addr-ans_offset][59:48]),
                        $signed(conv1_pw_ans_a2[addr-ans_offset][47:36]),   $signed(conv1_pw_ans_a2[addr-ans_offset][35:24]),
                        $signed(conv1_pw_ans_a2[addr-ans_offset][23:12]),   $signed(conv1_pw_ans_a2[addr-ans_offset][11:0]));
                end else if(layer == CONV2_PW)begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_pw_ans_a2[addr-ans_offset][191:180]), $signed(conv2_pw_ans_a2[addr-ans_offset][179:168]),
                        $signed(conv2_pw_ans_a2[addr-ans_offset][167:156]), $signed(conv2_pw_ans_a2[addr-ans_offset][155:144]), 
                        $signed(conv2_pw_ans_a2[addr-ans_offset][143:132]), $signed(conv2_pw_ans_a2[addr-ans_offset][131:120]),
                        $signed(conv2_pw_ans_a2[addr-ans_offset][119:108]), $signed(conv2_pw_ans_a2[addr-ans_offset][107:96]),
                        $signed(conv2_pw_ans_a2[addr-ans_offset][95:84]),   $signed(conv2_pw_ans_a2[addr-ans_offset][83:72]),
                        $signed(conv2_pw_ans_a2[addr-ans_offset][71:60]),   $signed(conv2_pw_ans_a2[addr-ans_offset][59:48]),
                        $signed(conv2_pw_ans_a2[addr-ans_offset][47:36]),   $signed(conv2_pw_ans_a2[addr-ans_offset][35:24]),
                        $signed(conv2_pw_ans_a2[addr-ans_offset][23:12]),   $signed(conv2_pw_ans_a2[addr-ans_offset][11:0]));
                end
            end
            A3: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n",
                    $signed(sram_36x192b_a3.mem[addr][191:180]), $signed(sram_36x192b_a3.mem[addr][179:168]),
                    $signed(sram_36x192b_a3.mem[addr][167:156]), $signed(sram_36x192b_a3.mem[addr][155:144]), 
                    $signed(sram_36x192b_a3.mem[addr][143:132]), $signed(sram_36x192b_a3.mem[addr][131:120]),
                    $signed(sram_36x192b_a3.mem[addr][119:108]), $signed(sram_36x192b_a3.mem[addr][107:96]),
                    $signed(sram_36x192b_a3.mem[addr][95:84]),   $signed(sram_36x192b_a3.mem[addr][83:72]),
                    $signed(sram_36x192b_a3.mem[addr][71:60]),   $signed(sram_36x192b_a3.mem[addr][59:48]),
                    $signed(sram_36x192b_a3.mem[addr][47:36]),   $signed(sram_36x192b_a3.mem[addr][35:24]),
                    $signed(sram_36x192b_a3.mem[addr][23:12]),   $signed(sram_36x192b_a3.mem[addr][11:0]));

                if(layer == UNSHUFFLE) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(unshuffle_ans_a3[addr-ans_offset][191:180]), $signed(unshuffle_ans_a3[addr-ans_offset][179:168]),
                        $signed(unshuffle_ans_a3[addr-ans_offset][167:156]), $signed(unshuffle_ans_a3[addr-ans_offset][155:144]), 
                        $signed(unshuffle_ans_a3[addr-ans_offset][143:132]), $signed(unshuffle_ans_a3[addr-ans_offset][131:120]),
                        $signed(unshuffle_ans_a3[addr-ans_offset][119:108]), $signed(unshuffle_ans_a3[addr-ans_offset][107:96]),
                        $signed(unshuffle_ans_a3[addr-ans_offset][95:84]),   $signed(unshuffle_ans_a3[addr-ans_offset][83:72]),
                        $signed(unshuffle_ans_a3[addr-ans_offset][71:60]),   $signed(unshuffle_ans_a3[addr-ans_offset][59:48]),
                        $signed(unshuffle_ans_a3[addr-ans_offset][47:36]),   $signed(unshuffle_ans_a3[addr-ans_offset][35:24]),
                        $signed(unshuffle_ans_a3[addr-ans_offset][23:12]),   $signed(unshuffle_ans_a3[addr-ans_offset][11:0]));
                end else if(layer == CONV1_PW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_pw_ans_a3[addr-ans_offset][191:180]), $signed(conv1_pw_ans_a3[addr-ans_offset][179:168]),
                        $signed(conv1_pw_ans_a3[addr-ans_offset][167:156]), $signed(conv1_pw_ans_a3[addr-ans_offset][155:144]), 
                        $signed(conv1_pw_ans_a3[addr-ans_offset][143:132]), $signed(conv1_pw_ans_a3[addr-ans_offset][131:120]),
                        $signed(conv1_pw_ans_a3[addr-ans_offset][119:108]), $signed(conv1_pw_ans_a3[addr-ans_offset][107:96]),
                        $signed(conv1_pw_ans_a3[addr-ans_offset][95:84]),   $signed(conv1_pw_ans_a3[addr-ans_offset][83:72]),
                        $signed(conv1_pw_ans_a3[addr-ans_offset][71:60]),   $signed(conv1_pw_ans_a3[addr-ans_offset][59:48]),
                        $signed(conv1_pw_ans_a3[addr-ans_offset][47:36]),   $signed(conv1_pw_ans_a3[addr-ans_offset][35:24]),
                        $signed(conv1_pw_ans_a3[addr-ans_offset][23:12]),   $signed(conv1_pw_ans_a3[addr-ans_offset][11:0]));
                end else if(layer == CONV2_PW)begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_pw_ans_a3[addr-ans_offset][191:180]), $signed(conv2_pw_ans_a3[addr-ans_offset][179:168]),
                        $signed(conv2_pw_ans_a3[addr-ans_offset][167:156]), $signed(conv2_pw_ans_a3[addr-ans_offset][155:144]), 
                        $signed(conv2_pw_ans_a3[addr-ans_offset][143:132]), $signed(conv2_pw_ans_a3[addr-ans_offset][131:120]),
                        $signed(conv2_pw_ans_a3[addr-ans_offset][119:108]), $signed(conv2_pw_ans_a3[addr-ans_offset][107:96]),
                        $signed(conv2_pw_ans_a3[addr-ans_offset][95:84]),   $signed(conv2_pw_ans_a3[addr-ans_offset][83:72]),
                        $signed(conv2_pw_ans_a3[addr-ans_offset][71:60]),   $signed(conv2_pw_ans_a3[addr-ans_offset][59:48]),
                        $signed(conv2_pw_ans_a3[addr-ans_offset][47:36]),   $signed(conv2_pw_ans_a3[addr-ans_offset][35:24]),
                        $signed(conv2_pw_ans_a3[addr-ans_offset][23:12]),   $signed(conv2_pw_ans_a3[addr-ans_offset][11:0]));
                end
            end
            B0: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_18x192b_b0.mem[addr][191:180]), $signed(sram_18x192b_b0.mem[addr][179:168]),
                    $signed(sram_18x192b_b0.mem[addr][167:156]), $signed(sram_18x192b_b0.mem[addr][155:144]), 
                    $signed(sram_18x192b_b0.mem[addr][143:132]), $signed(sram_18x192b_b0.mem[addr][131:120]),
                    $signed(sram_18x192b_b0.mem[addr][119:108]), $signed(sram_18x192b_b0.mem[addr][107:96]),
                    $signed(sram_18x192b_b0.mem[addr][95:84]),   $signed(sram_18x192b_b0.mem[addr][83:72]),
                    $signed(sram_18x192b_b0.mem[addr][71:60]),   $signed(sram_18x192b_b0.mem[addr][59:48]),
                    $signed(sram_18x192b_b0.mem[addr][47:36]),   $signed(sram_18x192b_b0.mem[addr][35:24]),
                    $signed(sram_18x192b_b0.mem[addr][23:12]),   $signed(sram_18x192b_b0.mem[addr][11:0]));
                if(layer == CONV1_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_dw_ans_b0[addr-ans_offset][191:180]), $signed(conv1_dw_ans_b0[addr-ans_offset][179:168]),
                        $signed(conv1_dw_ans_b0[addr-ans_offset][167:156]), $signed(conv1_dw_ans_b0[addr-ans_offset][155:144]), 
                        $signed(conv1_dw_ans_b0[addr-ans_offset][143:132]), $signed(conv1_dw_ans_b0[addr-ans_offset][131:120]),
                        $signed(conv1_dw_ans_b0[addr-ans_offset][119:108]), $signed(conv1_dw_ans_b0[addr-ans_offset][107:96]),
                        $signed(conv1_dw_ans_b0[addr-ans_offset][95:84]),   $signed(conv1_dw_ans_b0[addr-ans_offset][83:72]),
                        $signed(conv1_dw_ans_b0[addr-ans_offset][71:60]),   $signed(conv1_dw_ans_b0[addr-ans_offset][59:48]),
                        $signed(conv1_dw_ans_b0[addr-ans_offset][47:36]),   $signed(conv1_dw_ans_b0[addr-ans_offset][35:24]),
                        $signed(conv1_dw_ans_b0[addr-ans_offset][23:12]),   $signed(conv1_dw_ans_b0[addr-ans_offset][11:0]));
                end else if(layer == CONV2_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_dw_ans_b0[addr-ans_offset][191:180]), $signed(conv2_dw_ans_b0[addr-ans_offset][179:168]),
                        $signed(conv2_dw_ans_b0[addr-ans_offset][167:156]), $signed(conv2_dw_ans_b0[addr-ans_offset][155:144]), 
                        $signed(conv2_dw_ans_b0[addr-ans_offset][143:132]), $signed(conv2_dw_ans_b0[addr-ans_offset][131:120]),
                        $signed(conv2_dw_ans_b0[addr-ans_offset][119:108]), $signed(conv2_dw_ans_b0[addr-ans_offset][107:96]),
                        $signed(conv2_dw_ans_b0[addr-ans_offset][95:84]),   $signed(conv2_dw_ans_b0[addr-ans_offset][83:72]),
                        $signed(conv2_dw_ans_b0[addr-ans_offset][71:60]),   $signed(conv2_dw_ans_b0[addr-ans_offset][59:48]),
                        $signed(conv2_dw_ans_b0[addr-ans_offset][47:36]),   $signed(conv2_dw_ans_b0[addr-ans_offset][35:24]),
                        $signed(conv2_dw_ans_b0[addr-ans_offset][23:12]),   $signed(conv2_dw_ans_b0[addr-ans_offset][11:0]));
                end else if(layer == CONV3_POOL) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv3_pool_ans_b0[addr-ans_offset][191:180]), $signed(conv3_pool_ans_b0[addr-ans_offset][179:168]),
                        $signed(conv3_pool_ans_b0[addr-ans_offset][167:156]), $signed(conv3_pool_ans_b0[addr-ans_offset][155:144]), 
                        $signed(conv3_pool_ans_b0[addr-ans_offset][143:132]), $signed(conv3_pool_ans_b0[addr-ans_offset][131:120]),
                        $signed(conv3_pool_ans_b0[addr-ans_offset][119:108]), $signed(conv3_pool_ans_b0[addr-ans_offset][107:96]),
                        $signed(conv3_pool_ans_b0[addr-ans_offset][95:84]),   $signed(conv3_pool_ans_b0[addr-ans_offset][83:72]),
                        $signed(conv3_pool_ans_b0[addr-ans_offset][71:60]),   $signed(conv3_pool_ans_b0[addr-ans_offset][59:48]),
                        $signed(conv3_pool_ans_b0[addr-ans_offset][47:36]),   $signed(conv3_pool_ans_b0[addr-ans_offset][35:24]),
                        $signed(conv3_pool_ans_b0[addr-ans_offset][23:12]),   $signed(conv3_pool_ans_b0[addr-ans_offset][11:0]));
                end
            end
            B1: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_18x192b_b1.mem[addr][191:180]), $signed(sram_18x192b_b1.mem[addr][179:168]),
                    $signed(sram_18x192b_b1.mem[addr][167:156]), $signed(sram_18x192b_b1.mem[addr][155:144]), 
                    $signed(sram_18x192b_b1.mem[addr][143:132]), $signed(sram_18x192b_b1.mem[addr][131:120]),
                    $signed(sram_18x192b_b1.mem[addr][119:108]), $signed(sram_18x192b_b1.mem[addr][107:96]),
                    $signed(sram_18x192b_b1.mem[addr][95:84]),   $signed(sram_18x192b_b1.mem[addr][83:72]),
                    $signed(sram_18x192b_b1.mem[addr][71:60]),   $signed(sram_18x192b_b1.mem[addr][59:48]),
                    $signed(sram_18x192b_b1.mem[addr][47:36]),   $signed(sram_18x192b_b1.mem[addr][35:24]),
                    $signed(sram_18x192b_b1.mem[addr][23:12]),   $signed(sram_18x192b_b1.mem[addr][11:0]));
                if(layer == CONV1_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_dw_ans_b1[addr-ans_offset][191:180]), $signed(conv1_dw_ans_b1[addr-ans_offset][179:168]),
                        $signed(conv1_dw_ans_b1[addr-ans_offset][167:156]), $signed(conv1_dw_ans_b1[addr-ans_offset][155:144]), 
                        $signed(conv1_dw_ans_b1[addr-ans_offset][143:132]), $signed(conv1_dw_ans_b1[addr-ans_offset][131:120]),
                        $signed(conv1_dw_ans_b1[addr-ans_offset][119:108]), $signed(conv1_dw_ans_b1[addr-ans_offset][107:96]),
                        $signed(conv1_dw_ans_b1[addr-ans_offset][95:84]),   $signed(conv1_dw_ans_b1[addr-ans_offset][83:72]),
                        $signed(conv1_dw_ans_b1[addr-ans_offset][71:60]),   $signed(conv1_dw_ans_b1[addr-ans_offset][59:48]),
                        $signed(conv1_dw_ans_b1[addr-ans_offset][47:36]),   $signed(conv1_dw_ans_b1[addr-ans_offset][35:24]),
                        $signed(conv1_dw_ans_b1[addr-ans_offset][23:12]),   $signed(conv1_dw_ans_b1[addr-ans_offset][11:0]));
                end else if(layer == CONV2_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_dw_ans_b1[addr-ans_offset][191:180]), $signed(conv2_dw_ans_b1[addr-ans_offset][179:168]),
                        $signed(conv2_dw_ans_b1[addr-ans_offset][167:156]), $signed(conv2_dw_ans_b1[addr-ans_offset][155:144]), 
                        $signed(conv2_dw_ans_b1[addr-ans_offset][143:132]), $signed(conv2_dw_ans_b1[addr-ans_offset][131:120]),
                        $signed(conv2_dw_ans_b1[addr-ans_offset][119:108]), $signed(conv2_dw_ans_b1[addr-ans_offset][107:96]),
                        $signed(conv2_dw_ans_b1[addr-ans_offset][95:84]),   $signed(conv2_dw_ans_b1[addr-ans_offset][83:72]),
                        $signed(conv2_dw_ans_b1[addr-ans_offset][71:60]),   $signed(conv2_dw_ans_b1[addr-ans_offset][59:48]),
                        $signed(conv2_dw_ans_b1[addr-ans_offset][47:36]),   $signed(conv2_dw_ans_b1[addr-ans_offset][35:24]),
                        $signed(conv2_dw_ans_b1[addr-ans_offset][23:12]),   $signed(conv2_dw_ans_b1[addr-ans_offset][11:0]));
                end else if(layer == CONV3_POOL) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv3_pool_ans_b1[addr-ans_offset][191:180]), $signed(conv3_pool_ans_b1[addr-ans_offset][179:168]),
                        $signed(conv3_pool_ans_b1[addr-ans_offset][167:156]), $signed(conv3_pool_ans_b1[addr-ans_offset][155:144]), 
                        $signed(conv3_pool_ans_b1[addr-ans_offset][143:132]), $signed(conv3_pool_ans_b1[addr-ans_offset][131:120]),
                        $signed(conv3_pool_ans_b1[addr-ans_offset][119:108]), $signed(conv3_pool_ans_b1[addr-ans_offset][107:96]),
                        $signed(conv3_pool_ans_b1[addr-ans_offset][95:84]),   $signed(conv3_pool_ans_b1[addr-ans_offset][83:72]),
                        $signed(conv3_pool_ans_b1[addr-ans_offset][71:60]),   $signed(conv3_pool_ans_b1[addr-ans_offset][59:48]),
                        $signed(conv3_pool_ans_b1[addr-ans_offset][47:36]),   $signed(conv3_pool_ans_b1[addr-ans_offset][35:24]),
                        $signed(conv3_pool_ans_b1[addr-ans_offset][23:12]),   $signed(conv3_pool_ans_b1[addr-ans_offset][11:0]));
                end

            end
            B2: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_18x192b_b2.mem[addr][191:180]), $signed(sram_18x192b_b2.mem[addr][179:168]),
                    $signed(sram_18x192b_b2.mem[addr][167:156]), $signed(sram_18x192b_b2.mem[addr][155:144]), 
                    $signed(sram_18x192b_b2.mem[addr][143:132]), $signed(sram_18x192b_b2.mem[addr][131:120]),
                    $signed(sram_18x192b_b2.mem[addr][119:108]), $signed(sram_18x192b_b2.mem[addr][107:96]),
                    $signed(sram_18x192b_b2.mem[addr][95:84]),   $signed(sram_18x192b_b2.mem[addr][83:72]),
                    $signed(sram_18x192b_b2.mem[addr][71:60]),   $signed(sram_18x192b_b2.mem[addr][59:48]),
                    $signed(sram_18x192b_b2.mem[addr][47:36]),   $signed(sram_18x192b_b2.mem[addr][35:24]),
                    $signed(sram_18x192b_b2.mem[addr][23:12]),   $signed(sram_18x192b_b2.mem[addr][11:0]));
                if(layer == CONV1_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_dw_ans_b2[addr-ans_offset][191:180]), $signed(conv1_dw_ans_b2[addr-ans_offset][179:168]),
                        $signed(conv1_dw_ans_b2[addr-ans_offset][167:156]), $signed(conv1_dw_ans_b2[addr-ans_offset][155:144]), 
                        $signed(conv1_dw_ans_b2[addr-ans_offset][143:132]), $signed(conv1_dw_ans_b2[addr-ans_offset][131:120]),
                        $signed(conv1_dw_ans_b2[addr-ans_offset][119:108]), $signed(conv1_dw_ans_b2[addr-ans_offset][107:96]),
                        $signed(conv1_dw_ans_b2[addr-ans_offset][95:84]),   $signed(conv1_dw_ans_b2[addr-ans_offset][83:72]),
                        $signed(conv1_dw_ans_b2[addr-ans_offset][71:60]),   $signed(conv1_dw_ans_b2[addr-ans_offset][59:48]),
                        $signed(conv1_dw_ans_b2[addr-ans_offset][47:36]),   $signed(conv1_dw_ans_b2[addr-ans_offset][35:24]),
                        $signed(conv1_dw_ans_b2[addr-ans_offset][23:12]),   $signed(conv1_dw_ans_b2[addr-ans_offset][11:0]));
                end else if(layer == CONV2_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_dw_ans_b2[addr-ans_offset][191:180]), $signed(conv2_dw_ans_b2[addr-ans_offset][179:168]),
                        $signed(conv2_dw_ans_b2[addr-ans_offset][167:156]), $signed(conv2_dw_ans_b2[addr-ans_offset][155:144]), 
                        $signed(conv2_dw_ans_b2[addr-ans_offset][143:132]), $signed(conv2_dw_ans_b2[addr-ans_offset][131:120]),
                        $signed(conv2_dw_ans_b2[addr-ans_offset][119:108]), $signed(conv2_dw_ans_b2[addr-ans_offset][107:96]),
                        $signed(conv2_dw_ans_b2[addr-ans_offset][95:84]),   $signed(conv2_dw_ans_b2[addr-ans_offset][83:72]),
                        $signed(conv2_dw_ans_b2[addr-ans_offset][71:60]),   $signed(conv2_dw_ans_b2[addr-ans_offset][59:48]),
                        $signed(conv2_dw_ans_b2[addr-ans_offset][47:36]),   $signed(conv2_dw_ans_b2[addr-ans_offset][35:24]),
                        $signed(conv2_dw_ans_b2[addr-ans_offset][23:12]),   $signed(conv2_dw_ans_b2[addr-ans_offset][11:0]));
                end else if(layer == CONV3_POOL) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv3_pool_ans_b2[addr-ans_offset][191:180]), $signed(conv3_pool_ans_b2[addr-ans_offset][179:168]),
                        $signed(conv3_pool_ans_b2[addr-ans_offset][167:156]), $signed(conv3_pool_ans_b2[addr-ans_offset][155:144]), 
                        $signed(conv3_pool_ans_b2[addr-ans_offset][143:132]), $signed(conv3_pool_ans_b2[addr-ans_offset][131:120]),
                        $signed(conv3_pool_ans_b2[addr-ans_offset][119:108]), $signed(conv3_pool_ans_b2[addr-ans_offset][107:96]),
                        $signed(conv3_pool_ans_b2[addr-ans_offset][95:84]),   $signed(conv3_pool_ans_b2[addr-ans_offset][83:72]),
                        $signed(conv3_pool_ans_b2[addr-ans_offset][71:60]),   $signed(conv3_pool_ans_b2[addr-ans_offset][59:48]),
                        $signed(conv3_pool_ans_b2[addr-ans_offset][47:36]),   $signed(conv3_pool_ans_b2[addr-ans_offset][35:24]),
                        $signed(conv3_pool_ans_b2[addr-ans_offset][23:12]),   $signed(conv3_pool_ans_b2[addr-ans_offset][11:0]));
                end

            end
            B3: begin
                $write("Your answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n", 
                    $signed(sram_18x192b_b3.mem[addr][191:180]), $signed(sram_18x192b_b3.mem[addr][179:168]),
                    $signed(sram_18x192b_b3.mem[addr][167:156]), $signed(sram_18x192b_b3.mem[addr][155:144]), 
                    $signed(sram_18x192b_b3.mem[addr][143:132]), $signed(sram_18x192b_b3.mem[addr][131:120]),
                    $signed(sram_18x192b_b3.mem[addr][119:108]), $signed(sram_18x192b_b3.mem[addr][107:96]),
                    $signed(sram_18x192b_b3.mem[addr][95:84]),   $signed(sram_18x192b_b3.mem[addr][83:72]),
                    $signed(sram_18x192b_b3.mem[addr][71:60]),   $signed(sram_18x192b_b3.mem[addr][59:48]),
                    $signed(sram_18x192b_b3.mem[addr][47:36]),   $signed(sram_18x192b_b3.mem[addr][35:24]),
                    $signed(sram_18x192b_b3.mem[addr][23:12]),   $signed(sram_18x192b_b3.mem[addr][11:0]));
                if(layer == CONV1_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv1_dw_ans_b3[addr-ans_offset][191:180]), $signed(conv1_dw_ans_b3[addr-ans_offset][179:168]),
                        $signed(conv1_dw_ans_b3[addr-ans_offset][167:156]), $signed(conv1_dw_ans_b3[addr-ans_offset][155:144]), 
                        $signed(conv1_dw_ans_b3[addr-ans_offset][143:132]), $signed(conv1_dw_ans_b3[addr-ans_offset][131:120]),
                        $signed(conv1_dw_ans_b3[addr-ans_offset][119:108]), $signed(conv1_dw_ans_b3[addr-ans_offset][107:96]),
                        $signed(conv1_dw_ans_b3[addr-ans_offset][95:84]),   $signed(conv1_dw_ans_b3[addr-ans_offset][83:72]),
                        $signed(conv1_dw_ans_b3[addr-ans_offset][71:60]),   $signed(conv1_dw_ans_b3[addr-ans_offset][59:48]),
                        $signed(conv1_dw_ans_b3[addr-ans_offset][47:36]),   $signed(conv1_dw_ans_b3[addr-ans_offset][35:24]),
                        $signed(conv1_dw_ans_b3[addr-ans_offset][23:12]),   $signed(conv1_dw_ans_b3[addr-ans_offset][11:0]));
                end else if(layer == CONV2_DW) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv2_dw_ans_b3[addr-ans_offset][191:180]), $signed(conv2_dw_ans_b3[addr-ans_offset][179:168]),
                        $signed(conv2_dw_ans_b3[addr-ans_offset][167:156]), $signed(conv2_dw_ans_b3[addr-ans_offset][155:144]), 
                        $signed(conv2_dw_ans_b3[addr-ans_offset][143:132]), $signed(conv2_dw_ans_b3[addr-ans_offset][131:120]),
                        $signed(conv2_dw_ans_b3[addr-ans_offset][119:108]), $signed(conv2_dw_ans_b3[addr-ans_offset][107:96]),
                        $signed(conv2_dw_ans_b3[addr-ans_offset][95:84]),   $signed(conv2_dw_ans_b3[addr-ans_offset][83:72]),
                        $signed(conv2_dw_ans_b3[addr-ans_offset][71:60]),   $signed(conv2_dw_ans_b3[addr-ans_offset][59:48]),
                        $signed(conv2_dw_ans_b3[addr-ans_offset][47:36]),   $signed(conv2_dw_ans_b3[addr-ans_offset][35:24]),
                        $signed(conv2_dw_ans_b3[addr-ans_offset][23:12]),   $signed(conv2_dw_ans_b3[addr-ans_offset][11:0]));
                end else if(layer == CONV3_POOL) begin
                    $write("But the golden answer is \n%d %d %d %d (ch0)\n%d %d %d %d (ch1)\n%d %d %d %d (ch2)\n%d %d %d %d (ch3)\n\n", 
                        $signed(conv3_pool_ans_b3[addr-ans_offset][191:180]), $signed(conv3_pool_ans_b3[addr-ans_offset][179:168]),
                        $signed(conv3_pool_ans_b3[addr-ans_offset][167:156]), $signed(conv3_pool_ans_b3[addr-ans_offset][155:144]), 
                        $signed(conv3_pool_ans_b3[addr-ans_offset][143:132]), $signed(conv3_pool_ans_b3[addr-ans_offset][131:120]),
                        $signed(conv3_pool_ans_b3[addr-ans_offset][119:108]), $signed(conv3_pool_ans_b3[addr-ans_offset][107:96]),
                        $signed(conv3_pool_ans_b3[addr-ans_offset][95:84]),   $signed(conv3_pool_ans_b3[addr-ans_offset][83:72]),
                        $signed(conv3_pool_ans_b3[addr-ans_offset][71:60]),   $signed(conv3_pool_ans_b3[addr-ans_offset][59:48]),
                        $signed(conv3_pool_ans_b3[addr-ans_offset][47:36]),   $signed(conv3_pool_ans_b3[addr-ans_offset][35:24]),
                        $signed(conv3_pool_ans_b3[addr-ans_offset][23:12]),   $signed(conv3_pool_ans_b3[addr-ans_offset][11:0]));
                end
            end
        endcase
    end
endtask

endmodule