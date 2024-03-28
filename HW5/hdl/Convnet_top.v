//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

module Convnet_top #(
parameter CH_NUM = 4,
parameter ACT_PER_ADDR = 4,
parameter BW_PER_ACT = 12,
parameter WEIGHT_PER_ADDR = 9, 
parameter BIAS_PER_ADDR = 1,
parameter BW_PER_PARAM = 8
)
(
input clk,                          
input srst_n,     // synchronous reset (active low)
input enable,     // enable signal for notifying that the unshuffled image is ready in SRAM A
output reg valid, // output valid for testbench to check answers in corresponding SRAM groups
// read data from SRAM group A
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a0,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a1,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a2,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a3,
// read data from SRAM group B
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b0,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b1,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b2,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b3,
// read data from parameter SRAM
input [WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_weight,  
input [BIAS_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_bias,     
// read address to SRAM group A
output reg [6-1:0] sram_raddr_a0,
output reg [6-1:0] sram_raddr_a1,
output reg [6-1:0] sram_raddr_a2,
output reg [6-1:0] sram_raddr_a3,
// read address to SRAM group B
output reg [5-1:0] sram_raddr_b0,
output reg [5-1:0] sram_raddr_b1,
output reg [5-1:0] sram_raddr_b2,
output reg [5-1:0] sram_raddr_b3,
// read address to parameter SRAM
output reg [10-1:0] sram_raddr_weight,       
output reg [7-1:0] sram_raddr_bias,         
// write enable for SRAM groups A & B
output reg sram_wen_a0,
output reg sram_wen_a1,
output reg sram_wen_a2,
output reg sram_wen_a3,
output reg sram_wen_b0,
output reg sram_wen_b1,
output reg sram_wen_b2,
output reg sram_wen_b3,
// word mask for SRAM groups A & B
output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_a,
output reg [CH_NUM*ACT_PER_ADDR-1:0] sram_wordmask_b,
// write addrress to SRAM groups A & B
output reg [6-1:0] sram_waddr_a,
output reg [5-1:0] sram_waddr_b,
// write data to SRAM groups A & B
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_b
);

// read address to SRAM group A
reg [6-1:0] n_sram_raddr_a0;
reg [6-1:0] n_sram_raddr_a1;
reg [6-1:0] n_sram_raddr_a2;
reg [6-1:0] n_sram_raddr_a3;
// read address to SRAM group B
reg [5-1:0] n_sram_raddr_b0;
reg [5-1:0] n_sram_raddr_b1;
reg [5-1:0] n_sram_raddr_b2;
reg [5-1:0] n_sram_raddr_b3;
// read address to parameter SRAM
reg [10-1:0] n_sram_raddr_weight;       
reg [7-1:0] n_sram_raddr_bias;         
// write enable for SRAM groups A & B
reg n_sram_wen_a0;
reg n_sram_wen_a1;
reg n_sram_wen_a2;
reg n_sram_wen_a3;
reg n_sram_wen_b0;
reg n_sram_wen_b1;
reg n_sram_wen_b2;
reg n_sram_wen_b3;
// word mask for SRAM groups A & B
reg [CH_NUM*ACT_PER_ADDR-1:0] n_sram_wordmask_a;
reg [CH_NUM*ACT_PER_ADDR-1:0] n_sram_wordmask_b;
// write addrress to SRAM groups A & B
reg [6-1:0] n_sram_waddr_a;
reg [5-1:0] n_sram_waddr_b;
// write data to SRAM groups A & B
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_sram_wdata_a;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_sram_wdata_b;

reg n_valid;
reg [12-1:0] cnt, n_cnt;
reg [3-1:0] state, n_state;
localparam IDLE = 4'd0, PREP = 4'd1, CONV1_dw = 4'd2, CONV1_pw = 4'd3,
           CONV2_dw = 4'd4, CONV2_pw = 4'd5, CONV3_pl = 4'd6;
integer i,j;
reg pause;

//////////////////////////////////
//           CONV1_dw           //
//////////////////////////////////
// 6x6 data map for DW
reg signed [12-1:0] map0 [0:6*6-1];
reg signed [12-1:0] map1 [0:6*6-1];
reg signed [12-1:0] map2 [0:6*6-1];
reg signed [12-1:0] map3 [0:6*6-1];
reg signed [12-1:0] n_map0[0:6*6-1];
reg signed [12-1:0] n_map1[0:6*6-1];
reg signed [12-1:0] n_map2[0:6*6-1];
reg signed [12-1:0] n_map3[0:6*6-1]; 
// 9 weight for DW
reg signed [8-1:0] weight0_dw [0:6*3*3-1];
reg signed [8-1:0] weight1_dw [0:6*3*3-1];
reg signed [8-1:0] weight2_dw [0:6*3*3-1];
reg signed [8-1:0] weight3_dw [0:6*3*3-1];
reg signed [8-1:0] n_weight0_dw [0:6*3*3-1];
reg signed [8-1:0] n_weight1_dw [0:6*3*3-1];
reg signed [8-1:0] n_weight2_dw [0:6*3*3-1];
reg signed [8-1:0] n_weight3_dw [0:6*3*3-1];
// bias for DW
reg signed [8-1:0] bias_dw [0:4-1];
reg signed [8-1:0] n_bias_dw [0:4-1];
// calculation in sram B
reg signed [12-1:0] x_b0 [0:9-1];
reg signed [12-1:0] x_b1 [0:9-1];
reg signed [12-1:0] x_b2 [0:9-1];
reg signed [12-1:0] x_b3 [0:9-1];
reg signed [8-1:0] k_b0 [0:9-1];
reg signed [8-1:0] k_b1 [0:9-1];
reg signed [8-1:0] k_b2 [0:9-1];
reg signed [8-1:0] k_b3 [0:9-1];
reg signed [12+9-1:0] convolved_result_b0;
reg signed [12+9-1:0] convolved_result_b1;
reg signed [12+9-1:0] convolved_result_b2;
reg signed [12+9-1:0] convolved_result_b3;
reg signed [12+9-1:0] convolved_temp_b0 [0:4-1];
reg signed [12+9-1:0] convolved_temp_b1 [0:4-1];
reg signed [12+9-1:0] convolved_temp_b2 [0:4-1];
reg signed [12+9-1:0] convolved_temp_b3 [0:4-1];
reg signed [12+9-1:0] n_convolved_temp_b0 [0:4-1];
reg signed [12+9-1:0] n_convolved_temp_b1 [0:4-1];
reg signed [12+9-1:0] n_convolved_temp_b2 [0:4-1];
reg signed [12+9-1:0] n_convolved_temp_b3 [0:4-1];
reg signed [12+9-1:0] accumulated_result_b0;
reg signed [12+9-1:0] accumulated_result_b1;
reg signed [12+9-1:0] accumulated_result_b2;
reg signed [12+9-1:0] accumulated_result_b3;
reg signed [12+9-1:0] accumulated_temp_b0 [0:4-1];
reg signed [12+9-1:0] accumulated_temp_b1 [0:4-1];
reg signed [12+9-1:0] accumulated_temp_b2 [0:4-1];
reg signed [12+9-1:0] accumulated_temp_b3 [0:4-1];
reg signed [14-1:0] quantized_result_b0;
reg signed [14-1:0] quantized_result_b1;
reg signed [14-1:0] quantized_result_b2;
reg signed [14-1:0] quantized_result_b3;
//reg signed [14-1:0] quantized_temp_b0 [0:4-1];
//reg signed [14-1:0] quantized_temp_b1 [0:4-1];
//reg signed [14-1:0] quantized_temp_b2 [0:4-1];
//reg signed [14-1:0] quantized_temp_b3 [0:4-1];
//////////////////////////////////
//           CONV1_pw           //
//////////////////////////////////
// 2x2x4 feature map for PW
reg signed [12-1:0] feature_map0_pw [0:4*4-1];
reg signed [12-1:0] feature_map1_pw [0:4*4-1];
reg signed [12-1:0] feature_map2_pw [0:4*4-1];
reg signed [12-1:0] feature_map3_pw [0:4*4-1];
reg signed [12-1:0] n_feature_map0_pw [0:4*4-1];
reg signed [12-1:0] n_feature_map1_pw [0:4*4-1];
reg signed [12-1:0] n_feature_map2_pw [0:4*4-1];
reg signed [12-1:0] n_feature_map3_pw [0:4*4-1];
// 1 weight for PW
reg signed [8-1:0] weight_pw [0:12*4-1];
reg signed [8-1:0] n_weight_pw [0:12*4-1];
// bias for PW
reg signed [8-1:0] bias_pw [0:12-1];
reg signed [8-1:0] n_bias_pw [0:12-1];
// calculation in sram A
reg signed [12-1:0] x_a0 [0:4-1];
reg signed [12-1:0] x_a1 [0:4-1];
reg signed [12-1:0] x_a2 [0:4-1];
reg signed [12-1:0] x_a3 [0:4-1];
reg signed [8-1:0] k_a0 [0:4-1];
reg signed [8-1:0] k_a1 [0:4-1];
reg signed [8-1:0] k_a2 [0:4-1];
reg signed [8-1:0] k_a3 [0:4-1];
reg signed [12+9-1:0] convolved_result_a0;
reg signed [12+9-1:0] convolved_result_a1;
reg signed [12+9-1:0] convolved_result_a2;
reg signed [12+9-1:0] convolved_result_a3;
reg signed [12+9-1:0] accumulated_result_a0;
reg signed [12+9-1:0] accumulated_result_a1;
reg signed [12+9-1:0] accumulated_result_a2;
reg signed [12+9-1:0] accumulated_result_a3;
reg signed [14-1:0] quantized_result_a0;
reg signed [14-1:0] quantized_result_a1;
reg signed [14-1:0] quantized_result_a2;
reg signed [14-1:0] quantized_result_a3;

//fsm
always @* begin
    case (state) //synopys parallel_case
        IDLE: begin
            n_state = IDLE;
            n_valid = 0;
            if(enable) n_state = PREP;
        end
        PREP: begin
            n_state = PREP;
            n_valid = 0;
            if(sram_raddr_weight == 4) n_state = CONV1_dw;

        end
        CONV1_dw: begin
            n_state = CONV1_dw;
            n_valid = 0;
            if(cnt == 38) begin
                n_state = CONV1_pw;
                //n_valid = 1;
            end
        end
        CONV1_pw: begin
            n_state = CONV1_pw;
            n_valid = 0;
            if(cnt == 38) begin
                n_state = CONV2_dw;
                //n_valid = 1;
            end
        end
        CONV2_dw: begin
            n_state = CONV2_dw;
            n_valid = 0;
            if(cnt == 38) begin
                n_state = CONV2_pw;
                //n_valid = 1;
            end
        end
        CONV2_pw: begin
            n_state = CONV2_pw;
            n_valid = 0;
            if(cnt == 111) begin
                n_state = CONV3_pl;
                //n_valid = 1;
            end
        end
        CONV3_pl: begin
            n_state = CONV3_pl;
            n_valid = 0;
            if(cnt == 3076) begin
                n_state = IDLE;
                n_valid = 1;
                //$finish;
            end
        end
        default: begin
            n_state = IDLE;
            n_valid = 0;
        end
    endcase
end
//counter
always @* begin
    n_cnt = cnt;
    case (state) //synopys parallel_case
        IDLE: begin
            n_cnt = 0;
        end
        PREP: begin
            n_cnt = 0;
        end
        CONV1_dw: begin
            n_cnt = cnt + 1;
            if(cnt == 38) n_cnt = 0;
        end
        CONV1_pw: begin
            n_cnt = cnt + 1;
            if(cnt == 38) n_cnt = 0;
        end
        CONV2_dw: begin
            n_cnt = cnt + 1;
            if(cnt == 38) n_cnt = 0;
        end
        CONV2_pw: begin
            n_cnt = cnt + 1;
            if(cnt == 111) n_cnt = 0;
        end
        CONV3_pl: begin
            n_cnt = cnt + 1;
            if(cnt == 3076) n_cnt = 0;
        end
        default: begin
            n_cnt = cnt;
        end
    endcase 
end
//sram_A
always @* begin
    case (state) //synopys parallel_case
        IDLE: begin
            n_sram_wordmask_a = 16'b1111_1111_1111_1111;
            n_sram_raddr_a0 = 0;
            n_sram_raddr_a1 = 0;
            n_sram_raddr_a2 = 0;
            n_sram_raddr_a3 = 0;
            n_sram_waddr_a = 0;
            n_sram_wdata_a = 0;
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0;i<36;i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end 
        end  
        PREP: begin
            n_sram_wordmask_a = 16'b1111_1111_1111_1111;
            n_sram_raddr_a0 = 0;
            n_sram_raddr_a1 = 0;
            n_sram_raddr_a2 = 0;
            n_sram_raddr_a3 = 0;
            n_sram_waddr_a = 0;
            n_sram_wdata_a = 0;
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0;i<36;i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
        end
        CONV1_dw: begin
            n_sram_wordmask_a = 16'b1111_1111_1111_1111;
            n_sram_raddr_a0 = sram_raddr_a0;
            n_sram_raddr_a1 = sram_raddr_a1;
            n_sram_raddr_a2 = sram_raddr_a2;
            n_sram_raddr_a3 = sram_raddr_a3;
            n_sram_waddr_a = 0;
            n_sram_wdata_a = 0;
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0;i<36;i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
               
            case (1) //synopys parallel_case
                //(cnt%16) == 3 : begin
                (cnt%4) == 0: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 1;
                    n_sram_raddr_a1 = sram_raddr_a1 + 1;
                    n_sram_raddr_a2 = sram_raddr_a2 + 1;
                    n_sram_raddr_a3 = sram_raddr_a3 + 1;
                    {n_map0[28],n_map0[29],n_map0[34],n_map0[35]} = sram_rdata_a0[191:144];
                    {n_map1[28],n_map1[29],n_map1[34],n_map1[35]} = sram_rdata_a0[143:96];
                    {n_map2[28],n_map2[29],n_map2[34],n_map2[35]} = sram_rdata_a0[95:48];
                    {n_map3[28],n_map3[29],n_map3[34],n_map3[35]} = sram_rdata_a0[47:0];
                end
                //(cnt%16) == 7 : begin
                (cnt%4) == 1: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 3;
                    n_sram_raddr_a1 = sram_raddr_a1 + 3;
                    n_sram_raddr_a2 = sram_raddr_a2 + 3;
                    n_sram_raddr_a3 = sram_raddr_a3 + 3;

                    {n_map0[0],n_map0[1],n_map0[6],n_map0[7]} = sram_rdata_a0[191:144];
                    {n_map1[0],n_map1[1],n_map1[6],n_map1[7]} = sram_rdata_a0[143:96];
                    {n_map2[0],n_map2[1],n_map2[6],n_map2[7]} = sram_rdata_a0[95:48];
                    {n_map3[0],n_map3[1],n_map3[6],n_map3[7]} = sram_rdata_a0[47:0];

                    {n_map0[2],n_map0[3],n_map0[8],n_map0[9]} = sram_rdata_a1[191:144];
                    {n_map1[2],n_map1[3],n_map1[8],n_map1[9]} = sram_rdata_a1[143:96];
                    {n_map2[2],n_map2[3],n_map2[8],n_map2[9]} = sram_rdata_a1[95:48];
                    {n_map3[2],n_map3[3],n_map3[8],n_map3[9]} = sram_rdata_a1[47:0];

                    {n_map0[12],n_map0[13],n_map0[18],n_map0[19]} = sram_rdata_a2[191:144];
                    {n_map1[12],n_map1[13],n_map1[18],n_map1[19]} = sram_rdata_a2[143:96];
                    {n_map2[12],n_map2[13],n_map2[18],n_map2[19]} = sram_rdata_a2[95:48];
                    {n_map3[12],n_map3[13],n_map3[18],n_map3[19]} = sram_rdata_a2[47:0];

                    {n_map0[14],n_map0[15],n_map0[20],n_map0[21]} = sram_rdata_a3[191:144];
                    {n_map1[14],n_map1[15],n_map1[20],n_map1[21]} = sram_rdata_a3[143:96];
                    {n_map2[14],n_map2[15],n_map2[20],n_map2[21]} = sram_rdata_a3[95:48];
                    {n_map3[14],n_map3[15],n_map3[20],n_map3[21]} = sram_rdata_a3[47:0];
                end
                //(cnt%16) == 11: begin
                (cnt%4) == 2: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 1;
                    n_sram_raddr_a1 = sram_raddr_a1 + 1;
                    n_sram_raddr_a2 = sram_raddr_a2 + 1;
                    n_sram_raddr_a3 = sram_raddr_a3 + 1;

                    {n_map0[4],n_map0[5],n_map0[10],n_map0[11]} = sram_rdata_a0[191:144];
                    {n_map1[4],n_map1[5],n_map1[10],n_map1[11]} = sram_rdata_a0[143:96];
                    {n_map2[4],n_map2[5],n_map2[10],n_map2[11]} = sram_rdata_a0[95:48];
                    {n_map3[4],n_map3[5],n_map3[10],n_map3[11]} = sram_rdata_a0[47:0];

                    {n_map0[16],n_map0[17],n_map0[22],n_map0[23]} = sram_rdata_a2[191:144];
                    {n_map1[16],n_map1[17],n_map1[22],n_map1[23]} = sram_rdata_a2[143:96];
                    {n_map2[16],n_map2[17],n_map2[22],n_map2[23]} = sram_rdata_a2[95:48];
                    {n_map3[16],n_map3[17],n_map3[22],n_map3[23]} = sram_rdata_a2[47:0];
                end
                //(cnt%16) == 15: begin
                (cnt%4) == 3: begin
                    //if(cnt%144 == 143) begin
                    if(cnt%12 == 11) begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 3;
                        n_sram_raddr_a1 = sram_raddr_a1 - 3;
                        n_sram_raddr_a2 = sram_raddr_a2 - 3;
                        n_sram_raddr_a3 = sram_raddr_a3 - 3;
                    end
                    else begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 4;
                        n_sram_raddr_a1 = sram_raddr_a1 - 4;
                        n_sram_raddr_a2 = sram_raddr_a2 - 4;
                        n_sram_raddr_a3 = sram_raddr_a3 - 4; 
                    end

                    {n_map0[24],n_map0[25],n_map0[30],n_map0[31]} = sram_rdata_a0[191:144];
                    {n_map1[24],n_map1[25],n_map1[30],n_map1[31]} = sram_rdata_a0[143:96];
                    {n_map2[24],n_map2[25],n_map2[30],n_map2[31]} = sram_rdata_a0[95:48];
                    {n_map3[24],n_map3[25],n_map3[30],n_map3[31]} = sram_rdata_a0[47:0];

                    {n_map0[26],n_map0[27],n_map0[32],n_map0[33]} = sram_rdata_a1[191:144];
                    {n_map1[26],n_map1[27],n_map1[32],n_map1[33]} = sram_rdata_a1[143:96];
                    {n_map2[26],n_map2[27],n_map2[32],n_map2[33]} = sram_rdata_a1[95:48];
                    {n_map3[26],n_map3[27],n_map3[32],n_map3[33]} = sram_rdata_a1[47:0];
                end
                default: begin
                    n_sram_raddr_a0 = sram_raddr_a0;
                    n_sram_raddr_a1 = sram_raddr_a1;
                    n_sram_raddr_a2 = sram_raddr_a2;
                    n_sram_raddr_a3 = sram_raddr_a3;
                end
            endcase
            //if(cnt == 155) begin
            if(cnt == 38) begin
                n_sram_wordmask_a = 16'b1111_1111_1111_1111;
                n_sram_raddr_a0 = 0;
                n_sram_raddr_a1 = 0;
                n_sram_raddr_a2 = 0;
                n_sram_raddr_a3 = 0;
                n_sram_waddr_a = 0;
                n_sram_wdata_a = 0;
                n_sram_wen_a0 = 1;
                n_sram_wen_a1 = 1;
                n_sram_wen_a2 = 1;
                n_sram_wen_a3 = 1;
            end
            
        end
        CONV1_pw: begin
            n_sram_wordmask_a = 16'b0000_0000_0000_0000;
            n_sram_raddr_a0 = 0;
            n_sram_raddr_a1 = 0;
            n_sram_raddr_a2 = 0;
            n_sram_raddr_a3 = 0;
            n_sram_waddr_a = sram_waddr_a;
            n_sram_wdata_a = sram_wdata_a;
            if(cnt%4 == 2 & cnt > 3) begin
                n_sram_waddr_a = sram_waddr_a + 1;
                if(sram_waddr_a%4 == 2)  n_sram_waddr_a = sram_waddr_a + 2;
            end 
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0; i<36; i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
            for(i=0; i<4; i=i+1) begin
                {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = 0;
                {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = 0;
                {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = 0;
                {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = 0;
                case (1) //synopys parallel_case
                    (cnt%4 == 0): begin //calculate bank2 // output bank1
                        n_sram_wen_a2 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map2_pw[0],feature_map2_pw[1],feature_map2_pw[2],feature_map2_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map2_pw[4],feature_map2_pw[5],feature_map2_pw[6],feature_map2_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map2_pw[8],feature_map2_pw[9],feature_map2_pw[10],feature_map2_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map2_pw[12],feature_map2_pw[13],feature_map2_pw[14],feature_map2_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map2_pw[0][11]}},feature_map2_pw[0][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map2_pw[4][11]}},feature_map2_pw[4][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map2_pw[8][11]}},feature_map2_pw[8][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map2_pw[12][11]}},feature_map2_pw[12][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a1 = 
                        {{9{feature_map2_pw[1][11]}},feature_map2_pw[1][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map2_pw[5][11]}},feature_map2_pw[5][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map2_pw[9][11]}},feature_map2_pw[9][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map2_pw[13][11]}},feature_map2_pw[13][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a2 = 
                        {{9{feature_map2_pw[2][11]}},feature_map2_pw[2][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map2_pw[6][11]}},feature_map2_pw[6][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map2_pw[10][11]}},feature_map2_pw[10][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map2_pw[14][11]}},feature_map2_pw[14][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a3 = 
                        {{9{feature_map2_pw[3][11]}},feature_map2_pw[3][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map2_pw[7][11]}},feature_map2_pw[7][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map2_pw[11][11]}},feature_map2_pw[11][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map2_pw[15][11]}},feature_map2_pw[15][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
*/
                    end 
                    (cnt%4 == 1): begin //calculate bank3 // output bank2
                        n_sram_wen_a3 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map3_pw[0],feature_map3_pw[1],feature_map3_pw[2],feature_map3_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map3_pw[4],feature_map3_pw[5],feature_map3_pw[6],feature_map3_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map3_pw[8],feature_map3_pw[9],feature_map3_pw[10],feature_map3_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map3_pw[12],feature_map3_pw[13],feature_map3_pw[14],feature_map3_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map3_pw[0][11]}},feature_map3_pw[0][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map3_pw[4][11]}},feature_map3_pw[4][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map3_pw[8][11]}},feature_map3_pw[8][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map3_pw[12][11]}},feature_map3_pw[12][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a1 = 
                        {{9{feature_map3_pw[1][11]}},feature_map3_pw[1][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map3_pw[5][11]}},feature_map3_pw[5][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map3_pw[9][11]}},feature_map3_pw[9][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map3_pw[13][11]}},feature_map3_pw[13][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a2 = 
                        {{9{feature_map3_pw[2][11]}},feature_map3_pw[2][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map3_pw[6][11]}},feature_map3_pw[6][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map3_pw[10][11]}},feature_map3_pw[10][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map3_pw[14][11]}},feature_map3_pw[14][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a3 = 
                        {{9{feature_map3_pw[3][11]}},feature_map3_pw[3][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map3_pw[7][11]}},feature_map3_pw[7][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map3_pw[11][11]}},feature_map3_pw[11][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map3_pw[15][11]}},feature_map3_pw[15][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
*/
                    end
                    (cnt%4 == 2): begin //calculate bank0 // output bank3
                        if(cnt < 37) n_sram_wen_a0 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map0_pw[0],feature_map0_pw[1],feature_map0_pw[2],feature_map0_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map0_pw[4],feature_map0_pw[5],feature_map0_pw[6],feature_map0_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map0_pw[8],feature_map0_pw[9],feature_map0_pw[10],feature_map0_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map0_pw[12],feature_map0_pw[13],feature_map0_pw[14],feature_map0_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map0_pw[0][11]}},feature_map0_pw[0][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map0_pw[4][11]}},feature_map0_pw[4][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map0_pw[8][11]}},feature_map0_pw[8][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map0_pw[12][11]}},feature_map0_pw[12][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a1 = 
                        {{9{feature_map0_pw[1][11]}},feature_map0_pw[1][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map0_pw[5][11]}},feature_map0_pw[5][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map0_pw[9][11]}},feature_map0_pw[9][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map0_pw[13][11]}},feature_map0_pw[13][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a2 = 
                        {{9{feature_map0_pw[2][11]}},feature_map0_pw[2][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map0_pw[6][11]}},feature_map0_pw[6][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map0_pw[10][11]}},feature_map0_pw[10][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map0_pw[14][11]}},feature_map0_pw[14][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a3 = 
                        {{9{feature_map0_pw[3][11]}},feature_map0_pw[3][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map0_pw[7][11]}},feature_map0_pw[7][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map0_pw[11][11]}},feature_map0_pw[11][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map0_pw[15][11]}},feature_map0_pw[15][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
*/
                    end
                    (cnt%4 == 3): begin //calculate bank1 // output bank0
                        n_sram_wen_a1 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map1_pw[0],feature_map1_pw[1],feature_map1_pw[2],feature_map1_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map1_pw[4],feature_map1_pw[5],feature_map1_pw[6],feature_map1_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map1_pw[8],feature_map1_pw[9],feature_map1_pw[10],feature_map1_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map1_pw[12],feature_map1_pw[13],feature_map1_pw[14],feature_map1_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map1_pw[0][11]}},feature_map1_pw[0][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map1_pw[4][11]}},feature_map1_pw[4][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map1_pw[8][11]}},feature_map1_pw[8][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map1_pw[12][11]}},feature_map1_pw[12][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a1 = 
                        {{9{feature_map1_pw[1][11]}},feature_map1_pw[1][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map1_pw[5][11]}},feature_map1_pw[5][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map1_pw[9][11]}},feature_map1_pw[9][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map1_pw[13][11]}},feature_map1_pw[13][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a2 = 
                        {{9{feature_map1_pw[2][11]}},feature_map1_pw[2][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map1_pw[6][11]}},feature_map1_pw[6][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map1_pw[10][11]}},feature_map1_pw[10][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map1_pw[14][11]}},feature_map1_pw[14][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
                        convolved_result_a3 = 
                        {{9{feature_map1_pw[3][11]}},feature_map1_pw[3][10:0]} * {{13{weight_pw[0+i*4][7]}},weight_pw[0+i*4]}
                        + {{9{feature_map1_pw[7][11]}},feature_map1_pw[7][10:0]} * {{13{weight_pw[1+i*4][7]}},weight_pw[1+i*4]}
                        + {{9{feature_map1_pw[11][11]}},feature_map1_pw[11][10:0]} * {{13{weight_pw[2+i*4][7]}},weight_pw[2+i*4]}
                        + {{9{feature_map1_pw[15][11]}},feature_map1_pw[15][10:0]} * {{13{weight_pw[3+i*4][7]}},weight_pw[3+i*4]};
*/
                    end
                    default: begin
                    end
                endcase
                for(j=0; j<4; j=j+1) begin
                    k_a0[j] = weight_pw[j+i*4];
                    k_a1[j] = weight_pw[j+i*4];
                    k_a2[j] = weight_pw[j+i*4];
                    k_a3[j] = weight_pw[j+i*4];
                end
                convolved_result_a0 = x_a0[0] * k_a0[0] + x_a0[1] * k_a0[1] + x_a0[2] * k_a0[2] + x_a0[3] * k_a0[3]; 
                convolved_result_a1 = x_a1[0] * k_a1[0] + x_a1[1] * k_a1[1] + x_a1[2] * k_a1[2] + x_a1[3] * k_a1[3];
                convolved_result_a2 = x_a2[0] * k_a2[0] + x_a2[1] * k_a2[1] + x_a2[2] * k_a2[2] + x_a2[3] * k_a2[3];
                convolved_result_a3 = x_a3[0] * k_a3[0] + x_a3[1] * k_a3[1] + x_a3[2] * k_a3[2] + x_a3[3] * k_a3[3];
                accumulated_result_a0 = convolved_result_a0 + ({{5{bias_pw[i][7]}},bias_pw[i]} << 8);
                accumulated_result_a1 = convolved_result_a1 + ({{5{bias_pw[i][7]}},bias_pw[i]} << 8);
                accumulated_result_a2 = convolved_result_a2 + ({{5{bias_pw[i][7]}},bias_pw[i]} << 8);
                accumulated_result_a3 = convolved_result_a3 + ({{5{bias_pw[i][7]}},bias_pw[i]} << 8);
                if(accumulated_result_a0 < 0) accumulated_result_a0 = 0;
                if(accumulated_result_a1 < 0) accumulated_result_a1 = 0;
                if(accumulated_result_a2 < 0) accumulated_result_a2 = 0;
                if(accumulated_result_a3 < 0) accumulated_result_a3 = 0;
                quantized_result_a0 = (accumulated_result_a0 + 64) >>> 7;
                if(quantized_result_a0 > 2047) quantized_result_a0 = 2047;
                else if(quantized_result_a0 < -2048) quantized_result_a0 = -2048;
                quantized_result_a1 = (accumulated_result_a1 + 64) >>> 7;
                if(quantized_result_a1 > 2047) quantized_result_a1 = 2047;
                else if(quantized_result_a1 < -2048) quantized_result_a1 = -2048;
                quantized_result_a2 = (accumulated_result_a2 + 64) >>> 7;
                if(quantized_result_a2 > 2047) quantized_result_a2 = 2047;
                else if(quantized_result_a2 < -2048) quantized_result_a2 = -2048;
                quantized_result_a3 = (accumulated_result_a3 + 64) >>> 7;
                if(quantized_result_a3 > 2047) quantized_result_a3 = 2047;
                else if(quantized_result_a3 < -2048) quantized_result_a3 = -2048;

                //if(quantized_result_a1[11]) quantized_result_a1 = 0;
                //if(quantized_result_a2[11]) quantized_result_a2 = 0;
                //if(quantized_result_a3[11]) quantized_result_a3 = 0;
/*
                if(quantized_result_a0[12:11] == 2'b11) quantized_result_a0 = 0;
                if(quantized_result_a1[12:11] == 2'b11) quantized_result_a1 = 0;
                if(quantized_result_a2[12:11] == 2'b11) quantized_result_a2 = 0;
                if(quantized_result_a3[12:11] == 2'b11) quantized_result_a3 = 0;
*/
                case (i)
                    0: begin
                        n_sram_wdata_a[191:144] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end 
                    1: begin
                        n_sram_wdata_a[143:96] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end
                    2: begin
                        n_sram_wdata_a[95:48] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end
                    3: begin
                        n_sram_wdata_a[47:0] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end
                    default: begin
                    end
                endcase
            end
        end
        CONV2_dw: begin
            n_sram_wordmask_a = 16'b1111_1111_1111_1111;
            n_sram_raddr_a0 = sram_raddr_a0;
            n_sram_raddr_a1 = sram_raddr_a1;
            n_sram_raddr_a2 = sram_raddr_a2;
            n_sram_raddr_a3 = sram_raddr_a3;
            n_sram_waddr_a = 0;
            n_sram_wdata_a = 0;
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0;i<36;i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
               
            case (1) //synopys parallel_case
                (cnt%4) == 0: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 1;
                    n_sram_raddr_a1 = sram_raddr_a1 + 1;
                    n_sram_raddr_a2 = sram_raddr_a2 + 1;
                    n_sram_raddr_a3 = sram_raddr_a3 + 1;
                    {n_map0[28],n_map0[29],n_map0[34],n_map0[35]} = sram_rdata_a0[191:144];
                    {n_map1[28],n_map1[29],n_map1[34],n_map1[35]} = sram_rdata_a0[143:96];
                    {n_map2[28],n_map2[29],n_map2[34],n_map2[35]} = sram_rdata_a0[95:48];
                    {n_map3[28],n_map3[29],n_map3[34],n_map3[35]} = sram_rdata_a0[47:0];
                end
                (cnt%4) == 1: begin    
                    n_sram_raddr_a0 = sram_raddr_a0 + 3;
                    n_sram_raddr_a1 = sram_raddr_a1 + 3;
                    n_sram_raddr_a2 = sram_raddr_a2 + 3;
                    n_sram_raddr_a3 = sram_raddr_a3 + 3;
                    {n_map0[0],n_map0[1],n_map0[6],n_map0[7]} = sram_rdata_a0[191:144];
                    {n_map1[0],n_map1[1],n_map1[6],n_map1[7]} = sram_rdata_a0[143:96];
                    {n_map2[0],n_map2[1],n_map2[6],n_map2[7]} = sram_rdata_a0[95:48];
                    {n_map3[0],n_map3[1],n_map3[6],n_map3[7]} = sram_rdata_a0[47:0];

                    {n_map0[2],n_map0[3],n_map0[8],n_map0[9]} = sram_rdata_a1[191:144];
                    {n_map1[2],n_map1[3],n_map1[8],n_map1[9]} = sram_rdata_a1[143:96];
                    {n_map2[2],n_map2[3],n_map2[8],n_map2[9]} = sram_rdata_a1[95:48];
                    {n_map3[2],n_map3[3],n_map3[8],n_map3[9]} = sram_rdata_a1[47:0];

                    {n_map0[12],n_map0[13],n_map0[18],n_map0[19]} = sram_rdata_a2[191:144];
                    {n_map1[12],n_map1[13],n_map1[18],n_map1[19]} = sram_rdata_a2[143:96];
                    {n_map2[12],n_map2[13],n_map2[18],n_map2[19]} = sram_rdata_a2[95:48];
                    {n_map3[12],n_map3[13],n_map3[18],n_map3[19]} = sram_rdata_a2[47:0];

                    {n_map0[14],n_map0[15],n_map0[20],n_map0[21]} = sram_rdata_a3[191:144];
                    {n_map1[14],n_map1[15],n_map1[20],n_map1[21]} = sram_rdata_a3[143:96];
                    {n_map2[14],n_map2[15],n_map2[20],n_map2[21]} = sram_rdata_a3[95:48];
                    {n_map3[14],n_map3[15],n_map3[20],n_map3[21]} = sram_rdata_a3[47:0];
                end
                (cnt%4) == 2: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 1;
                    n_sram_raddr_a1 = sram_raddr_a1 + 1;
                    n_sram_raddr_a2 = sram_raddr_a2 + 1;
                    n_sram_raddr_a3 = sram_raddr_a3 + 1;

                    {n_map0[4],n_map0[5],n_map0[10],n_map0[11]} = sram_rdata_a0[191:144];
                    {n_map1[4],n_map1[5],n_map1[10],n_map1[11]} = sram_rdata_a0[143:96];
                    {n_map2[4],n_map2[5],n_map2[10],n_map2[11]} = sram_rdata_a0[95:48];
                    {n_map3[4],n_map3[5],n_map3[10],n_map3[11]} = sram_rdata_a0[47:0];

                    {n_map0[16],n_map0[17],n_map0[22],n_map0[23]} = sram_rdata_a2[191:144];
                    {n_map1[16],n_map1[17],n_map1[22],n_map1[23]} = sram_rdata_a2[143:96];
                    {n_map2[16],n_map2[17],n_map2[22],n_map2[23]} = sram_rdata_a2[95:48];
                    {n_map3[16],n_map3[17],n_map3[22],n_map3[23]} = sram_rdata_a2[47:0];
                end
                (cnt%4) == 3: begin
                    if(cnt%12 == 11) begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 3;
                        n_sram_raddr_a1 = sram_raddr_a1 - 3;
                        n_sram_raddr_a2 = sram_raddr_a2 - 3;
                        n_sram_raddr_a3 = sram_raddr_a3 - 3;
                    end
                    else begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 4;
                        n_sram_raddr_a1 = sram_raddr_a1 - 4;
                        n_sram_raddr_a2 = sram_raddr_a2 - 4;
                        n_sram_raddr_a3 = sram_raddr_a3 - 4; 
                    end

                    {n_map0[24],n_map0[25],n_map0[30],n_map0[31]} = sram_rdata_a0[191:144];
                    {n_map1[24],n_map1[25],n_map1[30],n_map1[31]} = sram_rdata_a0[143:96];
                    {n_map2[24],n_map2[25],n_map2[30],n_map2[31]} = sram_rdata_a0[95:48];
                    {n_map3[24],n_map3[25],n_map3[30],n_map3[31]} = sram_rdata_a0[47:0];

                    {n_map0[26],n_map0[27],n_map0[32],n_map0[33]} = sram_rdata_a1[191:144];
                    {n_map1[26],n_map1[27],n_map1[32],n_map1[33]} = sram_rdata_a1[143:96];
                    {n_map2[26],n_map2[27],n_map2[32],n_map2[33]} = sram_rdata_a1[95:48];
                    {n_map3[26],n_map3[27],n_map3[32],n_map3[33]} = sram_rdata_a1[47:0];
                end
                default: begin
                    n_sram_raddr_a0 = sram_raddr_a0;
                    n_sram_raddr_a1 = sram_raddr_a1;
                    n_sram_raddr_a2 = sram_raddr_a2;
                    n_sram_raddr_a3 = sram_raddr_a3;
                end
            endcase
            //$display("A_addr : %3d (%3d)",sram_raddr_a0,cnt);
            if(cnt == 38) begin
                n_sram_wordmask_a = 16'b1111_1111_1111_1111;
                n_sram_raddr_a0 = 0;
                n_sram_raddr_a1 = 0;
                n_sram_raddr_a2 = 0;
                n_sram_raddr_a3 = 0;
                n_sram_waddr_a = 0;
                n_sram_wdata_a = 0;
                n_sram_wen_a0 = 1;
                n_sram_wen_a1 = 1;
                n_sram_wen_a2 = 1;
                n_sram_wen_a3 = 1;
            end
        end
        CONV2_pw: begin
            n_sram_wordmask_a = 16'b0000_0000_0000_0000;
            n_sram_raddr_a0 = 0;
            n_sram_raddr_a1 = 0;
            n_sram_raddr_a2 = 0;
            n_sram_raddr_a3 = 0;
            n_sram_waddr_a = sram_waddr_a;
            n_sram_wdata_a = sram_wdata_a;
            if(cnt%4 == 2 & cnt > 3) begin
                n_sram_waddr_a = sram_waddr_a + 1;
                if(sram_waddr_a%4 == 2)  n_sram_waddr_a = sram_waddr_a + 2;
                
            end
            //$display("ADDR : %3d (%3d)",n_sram_waddr_a,cnt); 
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0; i<36; i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
            for(i=0; i<4; i=i+1) begin
                {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = 0;
                {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = 0;
                {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = 0;
                {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = 0;
                case (1)//synopys parallel_case
                    (cnt%4 == 0): begin //calculate bank2 // output bank1
                        if(cnt > 0) n_sram_wen_a2 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map2_pw[0],feature_map2_pw[1],feature_map2_pw[2],feature_map2_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map2_pw[4],feature_map2_pw[5],feature_map2_pw[6],feature_map2_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map2_pw[8],feature_map2_pw[9],feature_map2_pw[10],feature_map2_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map2_pw[12],feature_map2_pw[13],feature_map2_pw[14],feature_map2_pw[15]};
/*                        
                        convolved_result_a0 = 
                        {{9{feature_map2_pw[0][11]}},feature_map2_pw[0][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[4][11]}},feature_map2_pw[4][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[8][11]}},feature_map2_pw[8][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[12][11]}},feature_map2_pw[12][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a1 = 
                        {{9{feature_map2_pw[1][11]}},feature_map2_pw[1][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[5][11]}},feature_map2_pw[5][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[9][11]}},feature_map2_pw[9][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[13][11]}},feature_map2_pw[13][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a2 = 
                        {{9{feature_map2_pw[2][11]}},feature_map2_pw[2][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[6][11]}},feature_map2_pw[6][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[10][11]}},feature_map2_pw[10][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[14][11]}},feature_map2_pw[14][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a3 = 
                        {{9{feature_map2_pw[3][11]}},feature_map2_pw[3][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[7][11]}},feature_map2_pw[7][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[11][11]}},feature_map2_pw[11][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map2_pw[15][11]}},feature_map2_pw[15][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
*/
                    end 
                    (cnt%4 == 1): begin //calculate bank3 // output bank2
                        n_sram_wen_a3 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map3_pw[0],feature_map3_pw[1],feature_map3_pw[2],feature_map3_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map3_pw[4],feature_map3_pw[5],feature_map3_pw[6],feature_map3_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map3_pw[8],feature_map3_pw[9],feature_map3_pw[10],feature_map3_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map3_pw[12],feature_map3_pw[13],feature_map3_pw[14],feature_map3_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map3_pw[0][11]}},feature_map3_pw[0][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[4][11]}},feature_map3_pw[4][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[8][11]}},feature_map3_pw[8][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[12][11]}},feature_map3_pw[12][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a1 = 
                        {{9{feature_map3_pw[1][11]}},feature_map3_pw[1][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[5][11]}},feature_map3_pw[5][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[9][11]}},feature_map3_pw[9][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[13][11]}},feature_map3_pw[13][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a2 = 
                        {{9{feature_map3_pw[2][11]}},feature_map3_pw[2][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[6][11]}},feature_map3_pw[6][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[10][11]}},feature_map3_pw[10][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[14][11]}},feature_map3_pw[14][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a3 = 
                        {{9{feature_map3_pw[3][11]}},feature_map3_pw[3][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[7][11]}},feature_map3_pw[7][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[11][11]}},feature_map3_pw[11][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map3_pw[15][11]}},feature_map3_pw[15][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
*/
                    end
                    (cnt%4 == 2): begin //calculate bank0 // output bank3
                        n_sram_wen_a0 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map0_pw[0],feature_map0_pw[1],feature_map0_pw[2],feature_map0_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map0_pw[4],feature_map0_pw[5],feature_map0_pw[6],feature_map0_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map0_pw[8],feature_map0_pw[9],feature_map0_pw[10],feature_map0_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map0_pw[12],feature_map0_pw[13],feature_map0_pw[14],feature_map0_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map0_pw[0][11]}},feature_map0_pw[0][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[4][11]}},feature_map0_pw[4][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[8][11]}},feature_map0_pw[8][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[12][11]}},feature_map0_pw[12][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a1 = 
                        {{9{feature_map0_pw[1][11]}},feature_map0_pw[1][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[5][11]}},feature_map0_pw[5][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[9][11]}},feature_map0_pw[9][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[13][11]}},feature_map0_pw[13][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a2 = 
                        {{9{feature_map0_pw[2][11]}},feature_map0_pw[2][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[6][11]}},feature_map0_pw[6][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[10][11]}},feature_map0_pw[10][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[14][11]}},feature_map0_pw[14][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a3 = 
                        {{9{feature_map0_pw[3][11]}},feature_map0_pw[3][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[7][11]}},feature_map0_pw[7][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[11][11]}},feature_map0_pw[11][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map0_pw[15][11]}},feature_map0_pw[15][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
*/
                    end
                    (cnt%4 == 3): begin //calculate bank1 // output bank0
                        n_sram_wen_a1 = 0;
                        {x_a0[0],x_a1[0],x_a2[0],x_a3[0]} = {feature_map1_pw[0],feature_map1_pw[1],feature_map1_pw[2],feature_map1_pw[3]};
                        {x_a0[1],x_a1[1],x_a2[1],x_a3[1]} = {feature_map1_pw[4],feature_map1_pw[5],feature_map1_pw[6],feature_map1_pw[7]};
                        {x_a0[2],x_a1[2],x_a2[2],x_a3[2]} = {feature_map1_pw[8],feature_map1_pw[9],feature_map1_pw[10],feature_map1_pw[11]};
                        {x_a0[3],x_a1[3],x_a2[3],x_a3[3]} = {feature_map1_pw[12],feature_map1_pw[13],feature_map1_pw[14],feature_map1_pw[15]};
/*
                        convolved_result_a0 = 
                        {{9{feature_map1_pw[0][11]}},feature_map1_pw[0][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[4][11]}},feature_map1_pw[4][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[8][11]}},feature_map1_pw[8][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[12][11]}},feature_map1_pw[12][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a1 = 
                        {{9{feature_map1_pw[1][11]}},feature_map1_pw[1][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[5][11]}},feature_map1_pw[5][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[9][11]}},feature_map1_pw[9][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[13][11]}},feature_map1_pw[13][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a2 = 
                        {{9{feature_map1_pw[2][11]}},feature_map1_pw[2][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[6][11]}},feature_map1_pw[6][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[10][11]}},feature_map1_pw[10][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[14][11]}},feature_map1_pw[14][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
                        convolved_result_a3 = 
                        {{9{feature_map1_pw[3][11]}},feature_map1_pw[3][10:0]} * {{13{weight_pw[0+i*4+(cnt/37)*16][7]}},weight_pw[0+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[7][11]}},feature_map1_pw[7][10:0]} * {{13{weight_pw[1+i*4+(cnt/37)*16][7]}},weight_pw[1+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[11][11]}},feature_map1_pw[11][10:0]} * {{13{weight_pw[2+i*4+(cnt/37)*16][7]}},weight_pw[2+i*4+(cnt/37)*16]}
                        + {{9{feature_map1_pw[15][11]}},feature_map1_pw[15][10:0]} * {{13{weight_pw[3+i*4+(cnt/37)*16][7]}},weight_pw[3+i*4+(cnt/37)*16]};
*/
                    end
                    default: begin
                    end
                endcase
                for(j=0; j<4; j=j+1) begin
                    k_a0[j] = weight_pw[j+i*4+(cnt/37)*16];
                    k_a1[j] = weight_pw[j+i*4+(cnt/37)*16];
                    k_a2[j] = weight_pw[j+i*4+(cnt/37)*16];
                    k_a3[j] = weight_pw[j+i*4+(cnt/37)*16];
                end
                convolved_result_a0 = x_a0[0] * k_a0[0] + x_a0[1] * k_a0[1] + x_a0[2] * k_a0[2] + x_a0[3] * k_a0[3]; 
                convolved_result_a1 = x_a1[0] * k_a1[0] + x_a1[1] * k_a1[1] + x_a1[2] * k_a1[2] + x_a1[3] * k_a1[3];
                convolved_result_a2 = x_a2[0] * k_a2[0] + x_a2[1] * k_a2[1] + x_a2[2] * k_a2[2] + x_a2[3] * k_a2[3];
                convolved_result_a3 = x_a3[0] * k_a3[0] + x_a3[1] * k_a3[1] + x_a3[2] * k_a3[2] + x_a3[3] * k_a3[3];
                accumulated_result_a0 = convolved_result_a0 + ({{5{bias_pw[i+(cnt/37)*4][7]}},bias_pw[i+(cnt/37)*4]} << 8);
                accumulated_result_a1 = convolved_result_a1 + ({{5{bias_pw[i+(cnt/37)*4][7]}},bias_pw[i+(cnt/37)*4]} << 8);
                accumulated_result_a2 = convolved_result_a2 + ({{5{bias_pw[i+(cnt/37)*4][7]}},bias_pw[i+(cnt/37)*4]} << 8);
                accumulated_result_a3 = convolved_result_a3 + ({{5{bias_pw[i+(cnt/37)*4][7]}},bias_pw[i+(cnt/37)*4]} << 8);

                if(accumulated_result_a0 < 0) accumulated_result_a0 = 0;
                if(accumulated_result_a1 < 0) accumulated_result_a1 = 0;
                if(accumulated_result_a2 < 0) accumulated_result_a2 = 0;
                if(accumulated_result_a3 < 0) accumulated_result_a3 = 0;
                quantized_result_a0 = (accumulated_result_a0 + 64) >>> 7;
                if(quantized_result_a0 > 2047) quantized_result_a0 = 2047;
                else if(quantized_result_a0 < -2048) quantized_result_a0 = -2048;
                quantized_result_a1 = (accumulated_result_a1 + 64) >>> 7;
                if(quantized_result_a1 > 2047) quantized_result_a1 = 2047;
                else if(quantized_result_a1 < -2048) quantized_result_a1 = -2048;
                quantized_result_a2 = (accumulated_result_a2 + 64) >>> 7;
                if(quantized_result_a2 > 2047) quantized_result_a2 = 2047;
                else if(quantized_result_a2 < -2048) quantized_result_a2 = -2048;
                quantized_result_a3 = (accumulated_result_a3 + 64) >>> 7;
                if(quantized_result_a3 > 2047) quantized_result_a3 = 2047;
                else if(quantized_result_a3 < -2048) quantized_result_a3 = -2048;
/*
                if(quantized_result_a0[12:11] == 2'b11) quantized_result_a0 = 0;
                if(quantized_result_a1[12:11] == 2'b11) quantized_result_a1 = 0;
                if(quantized_result_a2[12:11] == 2'b11) quantized_result_a2 = 0;
                if(quantized_result_a3[12:11] == 2'b11) quantized_result_a3 = 0;
                if(quantized_result_a0[12:0] > 2047) quantized_result_a0 = 14'b00_011111111111;
                if(quantized_result_a1[12:0] > 2047) quantized_result_a1 = 14'b00_011111111111;
                if(quantized_result_a2[12:0] > 2047) quantized_result_a2 = 14'b00_011111111111;
                if(quantized_result_a3[12:0] > 2047) quantized_result_a3 = 14'b00_011111111111;

                if(accumulated_result_a0 < 0) accumulated_result_a0 = 0;
                if(accumulated_result_a1 < 0) accumulated_result_a1 = 0;
                if(accumulated_result_a2 < 0) accumulated_result_a2 = 0;
                if(accumulated_result_a3 < 0) accumulated_result_a3 = 0;
                if(quantized_result_a0[12:11] == 2'b11) quantized_result_a0 = 0;
                if(quantized_result_a1[12:11] == 2'b11) quantized_result_a1 = 0;
                if(quantized_result_a2[12:11] == 2'b11) quantized_result_a2 = 0;
                if(quantized_result_a3[12:11] == 2'b11) quantized_result_a3 = 0;
                if(quantized_result_a0[12:0] > 2047) quantized_result_a0 = 14'b00_011111111111;
                if(quantized_result_a1[12:0] > 2047) quantized_result_a1 = 14'b00_011111111111;
                if(quantized_result_a2[12:0] > 2047) quantized_result_a2 = 14'b00_011111111111;
                if(quantized_result_a3[12:0] > 2047) quantized_result_a3 = 14'b00_011111111111;

                if(quantized_result_a0 > 2047) quantized_result_a0 = 2047;
                //else if(quantized_result_a0 < -2048) quantized_result_a0 = -2048;
                if(quantized_result_a1 > 2047) quantized_result_a1 = 2047;
                //else if(quantized_result_a1 < -2048) quantized_result_a1 = -2048;
                if(quantized_result_a2 > 2047) quantized_result_a2 = 2047;
                //else if(quantized_result_a2 < -2048) quantized_result_a2 = -2048;
                if(quantized_result_a3 > 2047) quantized_result_a3 = 2047;
                //else if(quantized_result_a3 < -2048) quantized_result_a3 = -2048;
*/               
                //if(sram_waddr_a == 9 & (cnt%4 == 2)) $display("QUAN :[%5d][%5d][%5d][%5b]"
                //,quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3);
                case (i)
                    0: begin
                        n_sram_wdata_a[191:144] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end 
                    1: begin
                        n_sram_wdata_a[143:96] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end
                    2: begin
                        n_sram_wdata_a[95:48] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end
                    3: begin
                        n_sram_wdata_a[47:0] = {quantized_result_a0[11:0],quantized_result_a1[11:0],quantized_result_a2[11:0],quantized_result_a3[11:0]};
                    end
                    default: begin
                    end
                endcase

                //if(i == 0 & sram_waddr_a == 8) $display("block : %3d (%3d)",sram_waddr_a,cnt);
                //if(sram_waddr_a == 8) $write("%3d ",quantized_result_a3[11:0]);
                //if(i%2 == 1) $display("");
                //if(i == 3 & sram_waddr_a == 8) $display("");
                
            end
        end
        CONV3_pl: begin
            n_sram_wordmask_a = 16'b1111_1111_1111_1111;
            n_sram_raddr_a0 = sram_raddr_a0;
            n_sram_raddr_a1 = sram_raddr_a1;
            n_sram_raddr_a2 = sram_raddr_a2;
            n_sram_raddr_a3 = sram_raddr_a3;
            n_sram_waddr_a = 0;
            n_sram_wdata_a = 0;
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0;i<36;i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
               
            case (1) //synopys parallel_case
                (cnt%4) == 0: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 1;
                    n_sram_raddr_a1 = sram_raddr_a1 + 1;
                    n_sram_raddr_a2 = sram_raddr_a2 + 1;
                    n_sram_raddr_a3 = sram_raddr_a3 + 1;
                    {n_map0[28],n_map0[29],n_map0[34],n_map0[35]} = sram_rdata_a0[191:144];
                    {n_map1[28],n_map1[29],n_map1[34],n_map1[35]} = sram_rdata_a0[143:96];
                    {n_map2[28],n_map2[29],n_map2[34],n_map2[35]} = sram_rdata_a0[95:48];
                    {n_map3[28],n_map3[29],n_map3[34],n_map3[35]} = sram_rdata_a0[47:0];
                end
                (cnt%4) == 1: begin    
                    n_sram_raddr_a0 = sram_raddr_a0 + 3;
                    n_sram_raddr_a1 = sram_raddr_a1 + 3;
                    n_sram_raddr_a2 = sram_raddr_a2 + 3;
                    n_sram_raddr_a3 = sram_raddr_a3 + 3;
                    {n_map0[0],n_map0[1],n_map0[6],n_map0[7]} = sram_rdata_a0[191:144];
                    {n_map1[0],n_map1[1],n_map1[6],n_map1[7]} = sram_rdata_a0[143:96];
                    {n_map2[0],n_map2[1],n_map2[6],n_map2[7]} = sram_rdata_a0[95:48];
                    {n_map3[0],n_map3[1],n_map3[6],n_map3[7]} = sram_rdata_a0[47:0];

                    {n_map0[2],n_map0[3],n_map0[8],n_map0[9]} = sram_rdata_a1[191:144];
                    {n_map1[2],n_map1[3],n_map1[8],n_map1[9]} = sram_rdata_a1[143:96];
                    {n_map2[2],n_map2[3],n_map2[8],n_map2[9]} = sram_rdata_a1[95:48];
                    {n_map3[2],n_map3[3],n_map3[8],n_map3[9]} = sram_rdata_a1[47:0];

                    {n_map0[12],n_map0[13],n_map0[18],n_map0[19]} = sram_rdata_a2[191:144];
                    {n_map1[12],n_map1[13],n_map1[18],n_map1[19]} = sram_rdata_a2[143:96];
                    {n_map2[12],n_map2[13],n_map2[18],n_map2[19]} = sram_rdata_a2[95:48];
                    {n_map3[12],n_map3[13],n_map3[18],n_map3[19]} = sram_rdata_a2[47:0];

                    {n_map0[14],n_map0[15],n_map0[20],n_map0[21]} = sram_rdata_a3[191:144];
                    {n_map1[14],n_map1[15],n_map1[20],n_map1[21]} = sram_rdata_a3[143:96];
                    {n_map2[14],n_map2[15],n_map2[20],n_map2[21]} = sram_rdata_a3[95:48];
                    {n_map3[14],n_map3[15],n_map3[20],n_map3[21]} = sram_rdata_a3[47:0];
                end
                (cnt%4) == 2: begin
                    n_sram_raddr_a0 = sram_raddr_a0 + 1;
                    n_sram_raddr_a1 = sram_raddr_a1 + 1;
                    n_sram_raddr_a2 = sram_raddr_a2 + 1;
                    n_sram_raddr_a3 = sram_raddr_a3 + 1;

                    {n_map0[4],n_map0[5],n_map0[10],n_map0[11]} = sram_rdata_a0[191:144];
                    {n_map1[4],n_map1[5],n_map1[10],n_map1[11]} = sram_rdata_a0[143:96];
                    {n_map2[4],n_map2[5],n_map2[10],n_map2[11]} = sram_rdata_a0[95:48];
                    {n_map3[4],n_map3[5],n_map3[10],n_map3[11]} = sram_rdata_a0[47:0];

                    {n_map0[16],n_map0[17],n_map0[22],n_map0[23]} = sram_rdata_a2[191:144];
                    {n_map1[16],n_map1[17],n_map1[22],n_map1[23]} = sram_rdata_a2[143:96];
                    {n_map2[16],n_map2[17],n_map2[22],n_map2[23]} = sram_rdata_a2[95:48];
                    {n_map3[16],n_map3[17],n_map3[22],n_map3[23]} = sram_rdata_a2[47:0];
                end
                (cnt%4) == 3: begin
                    if(cnt%48 == 47) begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 34;
                        n_sram_raddr_a1 = sram_raddr_a1 - 34;
                        n_sram_raddr_a2 = sram_raddr_a2 - 34;
                        n_sram_raddr_a3 = sram_raddr_a3 - 34; 
                        
                    end
                    else if(cnt%24 == 23) begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 26;
                        n_sram_raddr_a1 = sram_raddr_a1 - 26;
                        n_sram_raddr_a2 = sram_raddr_a2 - 26;
                        n_sram_raddr_a3 = sram_raddr_a3 - 26;
                    end
                    else if(cnt%12 == 11) begin
                        n_sram_raddr_a0 = sram_raddr_a0 - 28;
                        n_sram_raddr_a1 = sram_raddr_a1 - 28;
                        n_sram_raddr_a2 = sram_raddr_a2 - 28;
                        n_sram_raddr_a3 = sram_raddr_a3 - 28;
                    end
                    else begin
                        n_sram_raddr_a0 = sram_raddr_a0 + 7;
                        n_sram_raddr_a1 = sram_raddr_a1 + 7;
                        n_sram_raddr_a2 = sram_raddr_a2 + 7;
                        n_sram_raddr_a3 = sram_raddr_a3 + 7; 
                    end

                    {n_map0[24],n_map0[25],n_map0[30],n_map0[31]} = sram_rdata_a0[191:144];
                    {n_map1[24],n_map1[25],n_map1[30],n_map1[31]} = sram_rdata_a0[143:96];
                    {n_map2[24],n_map2[25],n_map2[30],n_map2[31]} = sram_rdata_a0[95:48];
                    {n_map3[24],n_map3[25],n_map3[30],n_map3[31]} = sram_rdata_a0[47:0];

                    {n_map0[26],n_map0[27],n_map0[32],n_map0[33]} = sram_rdata_a1[191:144];
                    {n_map1[26],n_map1[27],n_map1[32],n_map1[33]} = sram_rdata_a1[143:96];
                    {n_map2[26],n_map2[27],n_map2[32],n_map2[33]} = sram_rdata_a1[95:48];
                    {n_map3[26],n_map3[27],n_map3[32],n_map3[33]} = sram_rdata_a1[47:0];
                end
                default: begin
                    n_sram_raddr_a0 = sram_raddr_a0;
                    n_sram_raddr_a1 = sram_raddr_a1;
                    n_sram_raddr_a2 = sram_raddr_a2;
                    n_sram_raddr_a3 = sram_raddr_a3;
                end
            endcase
/*
            $display("A_addr : %3d (%3d)",sram_raddr_a0,cnt);
            
            for(i=0;i<36;i=i+1) begin
                $write("[%5d]",map0[i]);
                if(i%6==5) $display("");
            end
            $display("");
            
            if(cnt == 48) begin
                n_sram_wordmask_a = 16'b1111_1111_1111_1111;
                n_sram_raddr_a0 = 0;
                n_sram_raddr_a1 = 0;
                n_sram_raddr_a2 = 0;
                n_sram_raddr_a3 = 0;
                n_sram_waddr_a = 0;
                n_sram_wdata_a = 0;
                n_sram_wen_a0 = 1;
                n_sram_wen_a1 = 1;
                n_sram_wen_a2 = 1;
                n_sram_wen_a3 = 1;
            end 
            */
        end
        default: begin
            n_sram_wordmask_a = 16'b1111_1111_1111_1111;
            n_sram_raddr_a0 = 0;
            n_sram_raddr_a1 = 0;
            n_sram_raddr_a2 = 0;
            n_sram_raddr_a3 = 0;
            n_sram_waddr_a = 0;
            n_sram_wdata_a = 0;
            n_sram_wen_a0 = 1;
            n_sram_wen_a1 = 1;
            n_sram_wen_a2 = 1;
            n_sram_wen_a3 = 1;
            for(i=0;i<36;i=i+1) begin
                n_map0[i] = map0[i];
                n_map1[i] = map1[i];
                n_map2[i] = map2[i];
                n_map3[i] = map3[i];
            end
        end
    endcase
end
//sram_B
always @* begin
    //n_sram_wordmask_b = 16'b1111_1111_1111_1111;
    for(i=0; i<4; i=i+1) begin
        n_convolved_temp_b0[i] = convolved_temp_b0[i];
        n_convolved_temp_b1[i] = convolved_temp_b1[i];
        n_convolved_temp_b2[i] = convolved_temp_b2[i];
        n_convolved_temp_b3[i] = convolved_temp_b3[i];
    end
    case (state) //synopys parallel_case
        IDLE: begin
            n_sram_wordmask_b = 16'b1111_1111_1111_1111;
            n_sram_raddr_b0 = 0;
            n_sram_raddr_b1 = 0;
            n_sram_raddr_b2 = 0;
            n_sram_raddr_b3 = 0;
            n_sram_waddr_b = 0;
            n_sram_wdata_b = 0;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            for(i=0; i<16; i=i+1) begin
                n_feature_map0_pw[i] = feature_map0_pw[i];
                n_feature_map1_pw[i] = feature_map1_pw[i];
                n_feature_map2_pw[i] = feature_map2_pw[i];
                n_feature_map3_pw[i] = feature_map3_pw[i];
            end
        end 
        PREP: begin
            n_sram_wordmask_b = 16'b1111_1111_1111_1111;
            n_sram_raddr_b0 = 0;
            n_sram_raddr_b1 = 0;
            n_sram_raddr_b2 = 0;
            n_sram_raddr_b3 = 0;
            n_sram_waddr_b = 0;
            n_sram_wdata_b = 0;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            for(i=0; i<16; i=i+1) begin
                n_feature_map0_pw[i] = feature_map0_pw[i];
                n_feature_map1_pw[i] = feature_map1_pw[i];
                n_feature_map2_pw[i] = feature_map2_pw[i];
                n_feature_map3_pw[i] = feature_map3_pw[i];
            end
        end
        CONV1_dw: begin
            n_sram_wordmask_b = 16'b0000_0000_0000_0000;
            n_sram_raddr_b0 = 0;
            n_sram_raddr_b1 = 0;
            n_sram_raddr_b2 = 0;
            n_sram_raddr_b3 = 0;
            n_sram_waddr_b = sram_waddr_b;
            //if(cnt%16 == 11 & cnt > 16) n_sram_waddr_b = sram_waddr_b + 1;
            if(cnt%4 == 2 & cnt > 3) n_sram_waddr_b = sram_waddr_b + 1;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            for(i=0; i<16; i=i+1) begin
                n_feature_map0_pw[i] = feature_map0_pw[i];
                n_feature_map1_pw[i] = feature_map1_pw[i];
                n_feature_map2_pw[i] = feature_map2_pw[i];
                n_feature_map3_pw[i] = feature_map3_pw[i];
            end
            
            for(i=0; i<4; i=i+1) begin
                for(j=0; j<9; j=j+1) begin
                    x_b0[j] = 0;
                    x_b1[j] = 0;
                    x_b2[j] = 0;
                    x_b3[j] = 0;
                    k_b0[j] = 0;
                    k_b1[j] = 0;
                    k_b2[j] = 0;
                    k_b3[j] = 0;
                end
                //if(i==0 & n_sram_waddr_b==0) $display("cnt : %3d , waddr_b : %3d ", cnt, n_sram_waddr_b);
                case (1) //synopys parallel_case
                    //(cnt%16) == 3 : begin //calculate bank2 // output bank1
                    (cnt%4) == 0 : begin
                        n_sram_wen_b2 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
/*
                            convolved_result_b0 = convolved_result_b0 
                                + {{9{map0[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j][7]}},weight0_dw[j]}; 

                                convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j][7]}},weight1_dw[j]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j][7]}},weight2_dw[j]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j][7]}},weight3_dw[j]}; 
*/
                        end
                    end
                    //(cnt%16) == 7 : begin //calculate bank3 // output bank2
                    (cnt%4) == 1 : begin
                        n_sram_wen_b3 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
/*
                            //convolved_result_b0 = convolved_result_b0 
                            //    + {{9{map0[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j][7]}},weight0_dw[j]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j][7]}},weight1_dw[j]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j][7]}},weight2_dw[j]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j][7]}},weight3_dw[j]}; 
*/
                            end
                    end
                    //(cnt%16) == 11: begin //calculate bank0 // output bank3
                    (cnt%4) == 2: begin
                        n_sram_wen_b0 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
/*
                            //convolved_result_b0 = convolved_result_b0 
                            //    + {{9{map0[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j][7]}},weight0_dw[j]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j][7]}},weight1_dw[j]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j][7]}},weight2_dw[j]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j][7]}},weight3_dw[j]}; 
*/
                        end
                    end
                    //(cnt%16) == 15: begin //calculate bank1 // output bank0
                    (cnt%4) == 3: begin
                        n_sram_wen_b1 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
/*
                            //convolved_result_b0 = convolved_result_b0 
                            //    + {{9{map0[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j][7]}},weight0_dw[j]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j][7]}},weight1_dw[j]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j][7]}},weight2_dw[j]};
                            convolved_result_b3 = convolved_result_b3 
                            + {{9{map3[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j][7]}},weight3_dw[j]}; 
*/
                        end
                    end
                    default: begin
                    end
                endcase
                convolved_result_b0 = x_b0[0] * k_b0[0] + x_b0[1] * k_b0[1] + x_b0[2] * k_b0[2] + x_b0[3] * k_b0[3] + x_b0[4] * k_b0[4]
                                    + x_b0[5] * k_b0[5] + x_b0[6] * k_b0[6] + x_b0[7] * k_b0[7] + x_b0[8] * k_b0[8];
                convolved_result_b1 = x_b1[0] * k_b1[0] + x_b1[1] * k_b1[1] + x_b1[2] * k_b1[2] + x_b1[3] * k_b1[3] + x_b1[4] * k_b1[4]
                                    + x_b1[5] * k_b1[5] + x_b1[6] * k_b1[6] + x_b1[7] * k_b1[7] + x_b1[8] * k_b1[8];
                convolved_result_b2 = x_b2[0] * k_b2[0] + x_b2[1] * k_b2[1] + x_b2[2] * k_b2[2] + x_b2[3] * k_b2[3] + x_b2[4] * k_b2[4]
                                    + x_b2[5] * k_b2[5] + x_b2[6] * k_b2[6] + x_b2[7] * k_b2[7] + x_b2[8] * k_b2[8];
                convolved_result_b3 = x_b3[0] * k_b3[0] + x_b3[1] * k_b3[1] + x_b3[2] * k_b3[2] + x_b3[3] * k_b3[3] + x_b3[4] * k_b3[4]
                                    + x_b3[5] * k_b3[5] + x_b3[6] * k_b3[6] + x_b3[7] * k_b3[7] + x_b3[8] * k_b3[8];
                accumulated_result_b0 = convolved_result_b0 + ({{5{bias_dw[0][7]}},bias_dw[0]} << 8);
                accumulated_result_b1 = convolved_result_b1 + ({{5{bias_dw[1][7]}},bias_dw[1]} << 8);
                accumulated_result_b2 = convolved_result_b2 + ({{5{bias_dw[2][7]}},bias_dw[2]} << 8);
                accumulated_result_b3 = convolved_result_b3 + ({{5{bias_dw[3][7]}},bias_dw[3]} << 8);
                quantized_result_b0 = (accumulated_result_b0 + 64) >>> 7;
                if(quantized_result_b0 > 2047) quantized_result_b0 = 2047;
                else if(quantized_result_b0 < -2048) quantized_result_b0 = -2048;
                quantized_result_b1 = (accumulated_result_b1 + 64) >>> 7;
                if(quantized_result_b1 > 2047) quantized_result_b1 = 2047;
                else if(quantized_result_b1 < -2048) quantized_result_b1 = -2048;
                quantized_result_b2 = (accumulated_result_b2 + 64) >>> 7;
                if(quantized_result_b2 > 2047) quantized_result_b2 = 2047;
                else if(quantized_result_b2 < -2048) quantized_result_b2 = -2048;
                quantized_result_b3 = (accumulated_result_b3 + 64) >>> 7;
                if(quantized_result_b3 > 2047) quantized_result_b3 = 2047;
                else if(quantized_result_b3 < -2048) quantized_result_b3 = -2048;
                
                case (i)
                    0: begin
                        n_sram_wdata_b[191:180] = quantized_result_b0[11:0];
                        n_sram_wdata_b[143:132] = quantized_result_b1[11:0];
                        n_sram_wdata_b[95:84]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[47:36]   = quantized_result_b3[11:0];
                        //$write("result0 : %b %3d/%3d ",n_sram_wdata_b[191],n_sram_wdata_b[190:180],2048-n_sram_wdata_b[190:180]);
                        //$write("result0 : -%3d ",2048-n_sram_wdata_b[190:180]);
                    end 
                    1: begin
                        n_sram_wdata_b[179:168] = quantized_result_b0[11:0];
                        n_sram_wdata_b[131:120] = quantized_result_b1[11:0];
                        n_sram_wdata_b[83:72]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[35:24]   = quantized_result_b3[11:0];
                        //$write("result1 : %b %3d/%3d ",n_sram_wdata_b[179],n_sram_wdata_b[178:168],2048-n_sram_wdata_b[178:168]);
                        //$write("result1 : -%3d ",2048-n_sram_wdata_b[178:168]);
                    end
                    2: begin
                        n_sram_wdata_b[167:156] = quantized_result_b0[11:0];
                        n_sram_wdata_b[119:108] = quantized_result_b1[11:0];
                        n_sram_wdata_b[71:60]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[23:12]   = quantized_result_b3[11:0];
                        //$write("result2 : %b %3d/%3d ",n_sram_wdata_b[167],n_sram_wdata_b[166:156],2048-n_sram_wdata_b[166:156]);
                        //$write("result2 : -%3d ",2048-n_sram_wdata_b[166:156]);
                    end
                    3: begin
                        n_sram_wdata_b[155:144] = quantized_result_b0[11:0];
                        n_sram_wdata_b[107:96]  = quantized_result_b1[11:0];
                        n_sram_wdata_b[59:48]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[11:0]    = quantized_result_b3[11:0];
                        //$write("result3 : %b %3d/%3d ",n_sram_wdata_b[155],n_sram_wdata_b[154:144],2048-n_sram_wdata_b[154:144]);
                        //$write("result3 : -%3d ",2048-n_sram_wdata_b[154:144]);
                    end
                    default: begin         
                    end
                endcase
                //if(i%2==1) $display("");
                //if(i==3) $display("");
            end
            //if(cnt%16 == 3) $display("RESU: %3d %3d %3d %3d (%3d)"
            //,n_sram_wdata_b[95:84],n_sram_wdata_b[83:72],n_sram_wdata_b[71:60],n_sram_wdata_b[59:48],n_sram_waddr_b);
        end
        CONV1_pw: begin
            n_sram_wordmask_b = 16'b1111_1111_1111_1111;
            n_sram_raddr_b0 = sram_raddr_b0;
            n_sram_raddr_b1 = sram_raddr_b1;
            n_sram_raddr_b2 = sram_raddr_b2;
            n_sram_raddr_b3 = sram_raddr_b3;
            n_sram_waddr_b = 0;
            n_sram_wdata_b = 0;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            //if(cnt%16 == 15) begin
            if(cnt%4 == 3) begin
                n_sram_raddr_b0 = sram_raddr_b0 + 1;
                n_sram_raddr_b1 = sram_raddr_b1 + 1;
                n_sram_raddr_b2 = sram_raddr_b2 + 1;
                n_sram_raddr_b3 = sram_raddr_b3 + 1;
            end

            {n_feature_map0_pw[0] ,n_feature_map0_pw[1] ,n_feature_map0_pw[2] ,n_feature_map0_pw[3],
             n_feature_map0_pw[4] ,n_feature_map0_pw[5] ,n_feature_map0_pw[6] ,n_feature_map0_pw[7],
             n_feature_map0_pw[8] ,n_feature_map0_pw[9] ,n_feature_map0_pw[10],n_feature_map0_pw[11],
             n_feature_map0_pw[12],n_feature_map0_pw[13],n_feature_map0_pw[14],n_feature_map0_pw[15]} = sram_rdata_b0;
            {n_feature_map1_pw[0] ,n_feature_map1_pw[1] ,n_feature_map1_pw[2] ,n_feature_map1_pw[3],
             n_feature_map1_pw[4] ,n_feature_map1_pw[5] ,n_feature_map1_pw[6] ,n_feature_map1_pw[7],
             n_feature_map1_pw[8] ,n_feature_map1_pw[9] ,n_feature_map1_pw[10],n_feature_map1_pw[11],
             n_feature_map1_pw[12],n_feature_map1_pw[13],n_feature_map1_pw[14],n_feature_map1_pw[15]} = sram_rdata_b1;
            {n_feature_map2_pw[0] ,n_feature_map2_pw[1] ,n_feature_map2_pw[2] ,n_feature_map2_pw[3],
             n_feature_map2_pw[4] ,n_feature_map2_pw[5] ,n_feature_map2_pw[6] ,n_feature_map2_pw[7],
             n_feature_map2_pw[8] ,n_feature_map2_pw[9] ,n_feature_map2_pw[10],n_feature_map2_pw[11],
             n_feature_map2_pw[12],n_feature_map2_pw[13],n_feature_map2_pw[14],n_feature_map2_pw[15]} = sram_rdata_b2;
            {n_feature_map3_pw[0] ,n_feature_map3_pw[1] ,n_feature_map3_pw[2] ,n_feature_map3_pw[3],
             n_feature_map3_pw[4] ,n_feature_map3_pw[5] ,n_feature_map3_pw[6] ,n_feature_map3_pw[7],
             n_feature_map3_pw[8] ,n_feature_map3_pw[9] ,n_feature_map3_pw[10],n_feature_map3_pw[11],
             n_feature_map3_pw[12],n_feature_map3_pw[13],n_feature_map3_pw[14],n_feature_map3_pw[15]} = sram_rdata_b3;
        end
        CONV2_dw: begin
            n_sram_wordmask_b = 16'b0000_0000_0000_0000;
            n_sram_raddr_b0 = 0;
            n_sram_raddr_b1 = 0;
            n_sram_raddr_b2 = 0;
            n_sram_raddr_b3 = 0;
            n_sram_waddr_b = sram_waddr_b;
            //if(cnt%16 == 11 & cnt > 16) n_sram_waddr_b = sram_waddr_b + 1;
            if(cnt%4 == 2 & cnt > 3) n_sram_waddr_b = sram_waddr_b + 1;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            for(i=0; i<16; i=i+1) begin
                n_feature_map0_pw[i] = feature_map0_pw[i];
                n_feature_map1_pw[i] = feature_map1_pw[i];
                n_feature_map2_pw[i] = feature_map2_pw[i];
                n_feature_map3_pw[i] = feature_map3_pw[i];
            end
            
            for(i=0; i<4; i=i+1) begin
                for(j=0; j<9; j=j+1) begin
                    x_b0[j] = 0;
                    x_b1[j] = 0;
                    x_b2[j] = 0;
                    x_b3[j] = 0;
                    k_b0[j] = 0;
                    k_b1[j] = 0;
                    k_b2[j] = 0;
                    k_b3[j] = 0;
                end
                //if(i==0 & n_sram_waddr_b==0) $display("cnt : %3d , waddr_b : %3d ", cnt, n_sram_waddr_b);
                case (1) //synopys parallel_case
                    //(cnt%16) == 3 : begin //calculate bank2 // output bank1
                    (cnt%4) == 0 : begin //calculate bank2 // output bank1
                        n_sram_wen_b2 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
                        end
                    end
                    (cnt%4) == 1 : begin //calculate bank3 // output bank2
                        n_sram_wen_b3 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
                        end
                    end
                    (cnt%4) == 2: begin //calculate bank0 // output bank3
                        n_sram_wen_b0 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
                        end
                    end
                    (cnt%4) == 3: begin //calculate bank1 // output bank0
                        n_sram_wen_b1 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j];
                            k_b1[j] = weight1_dw[j];
                            k_b2[j] = weight2_dw[j];
                            k_b3[j] = weight3_dw[j];
                        end
                    end
                    default: begin
                        
                    end
                endcase
                convolved_result_b0 = x_b0[0] * k_b0[0] + x_b0[1] * k_b0[1] + x_b0[2] * k_b0[2] + x_b0[3] * k_b0[3] + x_b0[4] * k_b0[4]
                                    + x_b0[5] * k_b0[5] + x_b0[6] * k_b0[6] + x_b0[7] * k_b0[7] + x_b0[8] * k_b0[8];
                convolved_result_b1 = x_b1[0] * k_b1[0] + x_b1[1] * k_b1[1] + x_b1[2] * k_b1[2] + x_b1[3] * k_b1[3] + x_b1[4] * k_b1[4]
                                    + x_b1[5] * k_b1[5] + x_b1[6] * k_b1[6] + x_b1[7] * k_b1[7] + x_b1[8] * k_b1[8];
                convolved_result_b2 = x_b2[0] * k_b2[0] + x_b2[1] * k_b2[1] + x_b2[2] * k_b2[2] + x_b2[3] * k_b2[3] + x_b2[4] * k_b2[4]
                                    + x_b2[5] * k_b2[5] + x_b2[6] * k_b2[6] + x_b2[7] * k_b2[7] + x_b2[8] * k_b2[8];
                convolved_result_b3 = x_b3[0] * k_b3[0] + x_b3[1] * k_b3[1] + x_b3[2] * k_b3[2] + x_b3[3] * k_b3[3] + x_b3[4] * k_b3[4]
                                    + x_b3[5] * k_b3[5] + x_b3[6] * k_b3[6] + x_b3[7] * k_b3[7] + x_b3[8] * k_b3[8];
                accumulated_result_b0 = convolved_result_b0 + ({{5{bias_dw[0][7]}},bias_dw[0]} << 8);
                accumulated_result_b1 = convolved_result_b1 + ({{5{bias_dw[1][7]}},bias_dw[1]} << 8);
                accumulated_result_b2 = convolved_result_b2 + ({{5{bias_dw[2][7]}},bias_dw[2]} << 8);
                accumulated_result_b3 = convolved_result_b3 + ({{5{bias_dw[3][7]}},bias_dw[3]} << 8);
                quantized_result_b0 = (accumulated_result_b0 + 64) >>> 7;
                if(quantized_result_b0 > 2047) quantized_result_b0 = 2047;
                else if(quantized_result_b0 < -2048) quantized_result_b0 = -2048;
                quantized_result_b1 = (accumulated_result_b1 + 64) >>> 7;
                if(quantized_result_b1 > 2047) quantized_result_b1 = 2047;
                else if(quantized_result_b1 < -2048) quantized_result_b1 = -2048;
                quantized_result_b2 = (accumulated_result_b2 + 64) >>> 7;
                if(quantized_result_b2 > 2047) quantized_result_b2 = 2047;
                else if(quantized_result_b2 < -2048) quantized_result_b2 = -2048;
                quantized_result_b3 = (accumulated_result_b3 + 64) >>> 7;
                if(quantized_result_b3 > 2047) quantized_result_b3 = 2047;
                else if(quantized_result_b3 < -2048) quantized_result_b3 = -2048;
                
                case (i)
                    0: begin
                        n_sram_wdata_b[191:180] = quantized_result_b0[11:0];
                        n_sram_wdata_b[143:132] = quantized_result_b1[11:0];
                        n_sram_wdata_b[95:84]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[47:36]   = quantized_result_b3[11:0];
                        //$write("result0 : %b %3d/%3d ",n_sram_wdata_b[191],n_sram_wdata_b[190:180],2048-n_sram_wdata_b[190:180]);
                        //$write("result0 : -%3d ",2048-n_sram_wdata_b[190:180]);
                    end 
                    1: begin
                        n_sram_wdata_b[179:168] = quantized_result_b0[11:0];
                        n_sram_wdata_b[131:120] = quantized_result_b1[11:0];
                        n_sram_wdata_b[83:72]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[35:24]   = quantized_result_b3[11:0];
                        //$write("result1 : %b %3d/%3d ",n_sram_wdata_b[179],n_sram_wdata_b[178:168],2048-n_sram_wdata_b[178:168]);
                        //$write("result1 : -%3d ",2048-n_sram_wdata_b[178:168]);
                    end
                    2: begin
                        n_sram_wdata_b[167:156] = quantized_result_b0[11:0];
                        n_sram_wdata_b[119:108] = quantized_result_b1[11:0];
                        n_sram_wdata_b[71:60]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[23:12]   = quantized_result_b3[11:0];
                        //$write("result2 : %b %3d/%3d ",n_sram_wdata_b[167],n_sram_wdata_b[166:156],2048-n_sram_wdata_b[166:156]);
                        //$write("result2 : -%3d ",2048-n_sram_wdata_b[166:156]);
                    end
                    3: begin
                        n_sram_wdata_b[155:144] = quantized_result_b0[11:0];
                        n_sram_wdata_b[107:96]  = quantized_result_b1[11:0];
                        n_sram_wdata_b[59:48]   = quantized_result_b2[11:0];
                        n_sram_wdata_b[11:0]    = quantized_result_b3[11:0];
                        //$write("result3 : %b %3d/%3d ",n_sram_wdata_b[155],n_sram_wdata_b[154:144],2048-n_sram_wdata_b[154:144]);
                        //$write("result3 : -%3d ",2048-n_sram_wdata_b[154:144]);
                    end
                    default: begin         
                    end
                endcase
                //if(sram_waddr_b == 6 & (cnt%4) == 2) $display("ACCU_RESULT : %3d",accumulated_result_b2);
                //if(sram_waddr_b == 6 & (cnt%4) == 2) $display("QUAN_RESULT : %3d",quantized_result_b2[11:0]);
                //if(sram_waddr_b == 6 & (cnt%4) == 2) $display("");
                //if(i%2==1) $display("");
                //if(i==3) $display("");
            end
            //if(cnt%16 == 3) $display("RESU: %3d %3d %3d %3d (%3d)"
            //,n_sram_wdata_b[95:84],n_sram_wdata_b[83:72],n_sram_wdata_b[71:60],n_sram_wdata_b[59:48],n_sram_waddr_b);
        end          
        CONV2_pw: begin
            n_sram_wordmask_b = 16'b1111_1111_1111_1111;
            n_sram_raddr_b0 = sram_raddr_b0;
            n_sram_raddr_b1 = sram_raddr_b1;
            n_sram_raddr_b2 = sram_raddr_b2;
            n_sram_raddr_b3 = sram_raddr_b3;
            n_sram_waddr_b = 0;
            n_sram_wdata_b = 0;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            if(cnt%4 == 3) begin
                n_sram_raddr_b0 = sram_raddr_b0 + 1;
                n_sram_raddr_b1 = sram_raddr_b1 + 1;
                n_sram_raddr_b2 = sram_raddr_b2 + 1;
                n_sram_raddr_b3 = sram_raddr_b3 + 1;
            end
            if(cnt%36 == 35) begin
                n_sram_raddr_b0 = 0;
                n_sram_raddr_b1 = 0;
                n_sram_raddr_b2 = 0;
                n_sram_raddr_b3 = 0;
            end

            {n_feature_map0_pw[0] ,n_feature_map0_pw[1] ,n_feature_map0_pw[2] ,n_feature_map0_pw[3],
             n_feature_map0_pw[4] ,n_feature_map0_pw[5] ,n_feature_map0_pw[6] ,n_feature_map0_pw[7],
             n_feature_map0_pw[8] ,n_feature_map0_pw[9] ,n_feature_map0_pw[10],n_feature_map0_pw[11],
             n_feature_map0_pw[12],n_feature_map0_pw[13],n_feature_map0_pw[14],n_feature_map0_pw[15]} = sram_rdata_b0;
            {n_feature_map1_pw[0] ,n_feature_map1_pw[1] ,n_feature_map1_pw[2] ,n_feature_map1_pw[3],
             n_feature_map1_pw[4] ,n_feature_map1_pw[5] ,n_feature_map1_pw[6] ,n_feature_map1_pw[7],
             n_feature_map1_pw[8] ,n_feature_map1_pw[9] ,n_feature_map1_pw[10],n_feature_map1_pw[11],
             n_feature_map1_pw[12],n_feature_map1_pw[13],n_feature_map1_pw[14],n_feature_map1_pw[15]} = sram_rdata_b1;
            {n_feature_map2_pw[0] ,n_feature_map2_pw[1] ,n_feature_map2_pw[2] ,n_feature_map2_pw[3],
             n_feature_map2_pw[4] ,n_feature_map2_pw[5] ,n_feature_map2_pw[6] ,n_feature_map2_pw[7],
             n_feature_map2_pw[8] ,n_feature_map2_pw[9] ,n_feature_map2_pw[10],n_feature_map2_pw[11],
             n_feature_map2_pw[12],n_feature_map2_pw[13],n_feature_map2_pw[14],n_feature_map2_pw[15]} = sram_rdata_b2;
            {n_feature_map3_pw[0] ,n_feature_map3_pw[1] ,n_feature_map3_pw[2] ,n_feature_map3_pw[3],
             n_feature_map3_pw[4] ,n_feature_map3_pw[5] ,n_feature_map3_pw[6] ,n_feature_map3_pw[7],
             n_feature_map3_pw[8] ,n_feature_map3_pw[9] ,n_feature_map3_pw[10],n_feature_map3_pw[11],
             n_feature_map3_pw[12],n_feature_map3_pw[13],n_feature_map3_pw[14],n_feature_map3_pw[15]} = sram_rdata_b3;
        end        
        CONV3_pl: begin
            case (1)
                ((cnt-3)%192) == 0  : n_sram_wordmask_b = 16'b0000_1111_1111_1111;
                ((cnt-3)%192) == 48 : n_sram_wordmask_b = 16'b1111_0000_1111_1111;
                ((cnt-3)%192) == 96 : n_sram_wordmask_b = 16'b1111_1111_0000_1111;
                ((cnt-3)%192) == 144: n_sram_wordmask_b = 16'b1111_1111_1111_0000;
                default: begin
                    n_sram_wordmask_b = sram_wordmask_b;
                end
            endcase
            n_sram_raddr_b0 = 0;
            n_sram_raddr_b1 = 0;
            n_sram_raddr_b2 = 0;
            n_sram_raddr_b3 = 0;
            n_sram_waddr_b = sram_waddr_b;
            if((cnt-3)%192 == 0 & cnt > 3) n_sram_waddr_b = sram_waddr_b + 1;
            n_sram_wdata_b = 0;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            for(i=0; i<16; i=i+1) begin
                n_feature_map0_pw[i] = feature_map0_pw[i];
                n_feature_map1_pw[i] = feature_map1_pw[i];
                n_feature_map2_pw[i] = feature_map2_pw[i];
                n_feature_map3_pw[i] = feature_map3_pw[i];
            end
            for(i=0; i<4; i=i+1) begin
                n_convolved_temp_b0[i] = convolved_temp_b0[i];
                n_convolved_temp_b1[i] = convolved_temp_b1[i];
                n_convolved_temp_b2[i] = convolved_temp_b2[i];
                n_convolved_temp_b3[i] = convolved_temp_b3[i];
            end
            if(cnt == 0) begin
                for(i=0; i<4; i=i+1) begin
                    n_convolved_temp_b0[i] = 0;
                    n_convolved_temp_b1[i] = 0;
                    n_convolved_temp_b2[i] = 0;
                    n_convolved_temp_b3[i] = 0;
                end                
            end


            //convolved_temp_b1[0] = 0;
            for(i=0; i<4; i=i+1) begin
                for(j=0; j<9; j=j+1) begin
                    x_b0[j] = 0;
                    x_b1[j] = 0;
                    x_b2[j] = 0;
                    x_b3[j] = 0;
                    k_b0[j] = 0;
                    k_b1[j] = 0;
                    k_b2[j] = 0;
                    k_b3[j] = 0;
                end

                //if(cnt == 0 & i== 0) convolved_temp_b2[0] = 0;
                //if(i==0 & n_sram_waddr_b==0) $display("cnt : %3d , waddr_b : %3d ", cnt, n_sram_waddr_b);
                case (1)
                    //(cnt%16) == 3 : begin //calculate bank2 // output bank1
                    (cnt%4) == 0 : begin //calculate bank2 // output bank1
                        //n_sram_wen_b2 = 0;
                        
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[12+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b1[j] = weight1_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b2[j] = weight2_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b3[j] = weight3_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            /*
                            convolved_result_b0 = convolved_result_b0 + map0[12+i%2+6*(i/2)+j%3+6*(j/3)] * weight0_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b1 = convolved_result_b1 + map1[12+i%2+6*(i/2)+j%3+6*(j/3)] * weight1_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b2 = convolved_result_b2 + map2[12+i%2+6*(i/2)+j%3+6*(j/3)] * weight2_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b3 = convolved_result_b3 + map3[12+i%2+6*(i/2)+j%3+6*(j/3)] * weight3_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            
                            convolved_result_b0 = convolved_result_b0 
                                + {{9{map0[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j+((cnt%12)/4)*9][7]}},weight0_dw[j+((cnt%12)/4)*9]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j+((cnt%12)/4)*9][7]}},weight1_dw[j+((cnt%12)/4)*9]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j+((cnt%12)/4)*9][7]}},weight2_dw[j+((cnt%12)/4)*9]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[12+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[12+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j+((cnt%12)/4)*9][7]}},weight3_dw[j+((cnt%12)/4)*9]}; 
                            */
                        end
/*
                        if(cnt < 3) n_convolved_temp_b2[i] = 0;
                        else if((cnt-4)%12 == 0) begin
                            //$display("cnt2 : %3d",cnt);
                            n_convolved_temp_b2[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        end
                        else n_convolved_temp_b2[i] = convolved_temp_b2[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
*/
                    end
                    (cnt%4) == 1 : begin //calculate bank3 // output bank2
                        //n_sram_wen_b3 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[14+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b1[j] = weight1_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b2[j] = weight2_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b3[j] = weight3_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
/*
                            convolved_result_b0 = convolved_result_b0 + map0[14+i%2+6*(i/2)+j%3+6*(j/3)] * weight0_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b1 = convolved_result_b1 + map1[14+i%2+6*(i/2)+j%3+6*(j/3)] * weight1_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b2 = convolved_result_b2 + map2[14+i%2+6*(i/2)+j%3+6*(j/3)] * weight2_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b3 = convolved_result_b3 + map3[14+i%2+6*(i/2)+j%3+6*(j/3)] * weight3_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            
                            convolved_result_b0 = convolved_result_b0 
                                + {{9{map0[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j+(((cnt-2)%12)/4)*9][7]}},weight0_dw[j+(((cnt-2)%12)/4)*9]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j+(((cnt-2)%12)/4)*9][7]}},weight1_dw[j+(((cnt-2)%12)/4)*9]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j+(((cnt-2)%12)/4)*9][7]}},weight2_dw[j+(((cnt-2)%12)/4)*9]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[14+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[14+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j+(((cnt-2)%12)/4)*9][7]}},weight3_dw[j+(((cnt-2)%12)/4)*9]}; 
                        */
                        end
/*
                        if(cnt < 3) n_convolved_temp_b3[i] = 0;
                        else if((cnt-4)%12 == 1) n_convolved_temp_b3[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b3[i] = convolved_temp_b3[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
*/
                    end
                    (cnt%4) == 2: begin //calculate bank0 // output bank3
                        //n_sram_wen_b0 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b1[j] = weight1_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b2[j] = weight2_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b3[j] = weight3_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
/*
                            convolved_result_b0 = convolved_result_b0 + map0[i%2+6*(i/2)+j%3+6*(j/3)] * weight0_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b1 = convolved_result_b1 + map1[i%2+6*(i/2)+j%3+6*(j/3)] * weight1_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b2 = convolved_result_b2 + map2[i%2+6*(i/2)+j%3+6*(j/3)] * weight2_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b3 = convolved_result_b3 + map3[i%2+6*(i/2)+j%3+6*(j/3)] * weight3_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            //if(cnt == 114) $write("(%3d,%5d)[%b]",(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27,sram_raddr_a0,weight0_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27]);
                            
                            convolved_result_b0 = convolved_result_b0 
                                + {{9{map0[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j+(((cnt-2)%12)/4)*9][7]}},weight0_dw[j+(((cnt-2)%12)/4)*9]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j+(((cnt-2)%12)/4)*9][7]}},weight1_dw[j+(((cnt-2)%12)/4)*9]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j+(((cnt-2)%12)/4)*9][7]}},weight2_dw[j+(((cnt-2)%12)/4)*9]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j+(((cnt-2)%12)/4)*9][7]}},weight3_dw[j+(((cnt-2)%12)/4)*9]}; 
                            //if(sram_waddr_b == 6)$write("%b_%3d * %b_%3d",map2[i%2+6*(i/2)+j%3+6*(j/3)][11],map2[i%2+6*(i/2)+j%3+6*(j/3)][10:0],
                            //weight2_dw[j+((cnt%12)/4)*9][7],weight2_dw[j+((cnt%12)/4)*9][6:0]);
                            //if(sram_waddr_b == 6)$display("");
*/  
                        end
/*
                        if(cnt%12 == 2) n_convolved_temp_b0[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b0[i] = convolved_temp_b0[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
*/
                    end
                    (cnt%4) == 3: begin //calculate bank1 // output bank0
                        //n_sram_wen_b1 = 0;
                        for(j=0; j<9; j=j+1) begin
                            x_b0[j] = map0[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b1[j] = map1[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b2[j] = map2[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            x_b3[j] = map3[2+i%2+6*(i/2)+j%3+6*(j/3)];
                            k_b0[j] = weight0_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b1[j] = weight1_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b2[j] = weight2_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
                            k_b3[j] = weight3_dw[j+(((cnt-2)%12)>>2)*9+(((cnt-2)%96)/48)*27];
/*
                            convolved_result_b0 = convolved_result_b0 + map0[2+i%2+6*(i/2)+j%3+6*(j/3)] * weight0_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b1 = convolved_result_b1 + map1[2+i%2+6*(i/2)+j%3+6*(j/3)] * weight1_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b2 = convolved_result_b2 + map2[2+i%2+6*(i/2)+j%3+6*(j/3)] * weight2_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];
                            convolved_result_b3 = convolved_result_b3 + map3[2+i%2+6*(i/2)+j%3+6*(j/3)] * weight3_dw[j+(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27];

                            convolved_result_b0 = convolved_result_b0 
                                + {{9{map0[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map0[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight0_dw[j+((cnt%12)/4)*9][7]}},weight0_dw[j+((cnt%12)/4)*9]}; 
                            convolved_result_b1 = convolved_result_b1 
                                + {{9{map1[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map1[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight1_dw[j+((cnt%12)/4)*9][7]}},weight1_dw[j+((cnt%12)/4)*9]};
                            convolved_result_b2 = convolved_result_b2 
                                + {{9{map2[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map2[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight2_dw[j+((cnt%12)/4)*9][7]}},weight2_dw[j+((cnt%12)/4)*9]};
                            convolved_result_b3 = convolved_result_b3 
                                + {{9{map3[2+i%2+6*(i/2)+j%3+6*(j/3)][11]}},map3[2+i%2+6*(i/2)+j%3+6*(j/3)]} * {{13{weight3_dw[j+((cnt%12)/4)*9][7]}},weight3_dw[j+((cnt%12)/4)*9]}; 
*/
                        end
/*
                        if(cnt%12 == 3) n_convolved_temp_b1[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b1[i] = convolved_temp_b1[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
*/
                        //else convolved_temp_b1[i] = 0;
                    end
                    default: begin
                    end
                endcase
                convolved_result_b0 = x_b0[0] * k_b0[0] + x_b0[1] * k_b0[1] + x_b0[2] * k_b0[2] + x_b0[3] * k_b0[3] + x_b0[4] * k_b0[4]
                                    + x_b0[5] * k_b0[5] + x_b0[6] * k_b0[6] + x_b0[7] * k_b0[7] + x_b0[8] * k_b0[8];
                convolved_result_b1 = x_b1[0] * k_b1[0] + x_b1[1] * k_b1[1] + x_b1[2] * k_b1[2] + x_b1[3] * k_b1[3] + x_b1[4] * k_b1[4]
                                    + x_b1[5] * k_b1[5] + x_b1[6] * k_b1[6] + x_b1[7] * k_b1[7] + x_b1[8] * k_b1[8];
                convolved_result_b2 = x_b2[0] * k_b2[0] + x_b2[1] * k_b2[1] + x_b2[2] * k_b2[2] + x_b2[3] * k_b2[3] + x_b2[4] * k_b2[4]
                                    + x_b2[5] * k_b2[5] + x_b2[6] * k_b2[6] + x_b2[7] * k_b2[7] + x_b2[8] * k_b2[8];
                convolved_result_b3 = x_b3[0] * k_b3[0] + x_b3[1] * k_b3[1] + x_b3[2] * k_b3[2] + x_b3[3] * k_b3[3] + x_b3[4] * k_b3[4]
                                    + x_b3[5] * k_b3[5] + x_b3[6] * k_b3[6] + x_b3[7] * k_b3[7] + x_b3[8] * k_b3[8];
                case (1)
                    (cnt%4) == 0 : begin //calculate bank2 // output bank1
                        if(cnt < 3) n_convolved_temp_b2[i] = 0;
                        else if((cnt-4)%12 == 0) n_convolved_temp_b2[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b2[i] = convolved_temp_b2[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                    end
                    (cnt%4) == 1 : begin //calculate bank3 // output bank2
                        if(cnt < 3) n_convolved_temp_b3[i] = 0;
                        else if((cnt-4)%12 == 1) n_convolved_temp_b3[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b3[i] = convolved_temp_b3[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        if(cnt < 326 & cnt > 314) begin
                            //$display("%3d",(((cnt-2)%12)/4)*9+(((cnt-2)%96)/48)*27);
                            //for(j=0;j<9;j=j+1)$write("%b_",k_b3[j]);
                            //$display("");
                            //$display("CONVT : %3d",n_convolved_temp_b3[i]);
                        end
                    end
                    (cnt%4) == 2: begin //calculate bank0 // output bank3
                        if(cnt%12 == 2) n_convolved_temp_b0[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b0[i] = convolved_temp_b0[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                    end
                    (cnt%4) == 3: begin //calculate bank1 // output bank0
                        if(cnt%12 == 3) n_convolved_temp_b1[i] = convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                        else n_convolved_temp_b1[i] = convolved_temp_b1[i] + convolved_result_b0 + convolved_result_b1 + convolved_result_b2 + convolved_result_b3;
                    end
                    default: begin
                    end
                endcase
            end
            if(((cnt-3)%12) == 11) begin
                //$display("bais : %3d",bias_dw[((cnt-3)/48)%2]);
                /*
                if(cnt == 326) begin
                    for(j=0;j<4;j=j+1) begin
                        $display("ACCU0 : %3d",convolved_temp_b3[j]);
                    end
                end
                */
                for(i=0; i<4; i=i+1) begin
                    accumulated_temp_b0[i] = convolved_temp_b0[i] + ({{5{bias_dw[((cnt-3)/48)%2][7]}},bias_dw[((cnt-3)/48)%2]} << 8);
                    accumulated_temp_b1[i] = convolved_temp_b1[i] + ({{5{bias_dw[((cnt-3)/48)%2][7]}},bias_dw[((cnt-3)/48)%2]} << 8);
                    accumulated_temp_b2[i] = convolved_temp_b2[i] + ({{5{bias_dw[((cnt-3)/48)%2][7]}},bias_dw[((cnt-3)/48)%2]} << 8);
                    accumulated_temp_b3[i] = convolved_temp_b3[i] + ({{5{bias_dw[((cnt-3)/48)%2][7]}},bias_dw[((cnt-3)/48)%2]} << 8);

                    if(accumulated_temp_b0[i] < 0) accumulated_temp_b0[i] = 0;
                    //else relu_result_b0[i] = accumulated_temp_b0[i];
                    if(accumulated_temp_b1[i] < 0) accumulated_temp_b1[i] = 0;
                    //else relu_result_b1[i] = accumulated_temp_b1[i];
                    if(accumulated_temp_b2[i] < 0) accumulated_temp_b2[i] = 0;
                    //else relu_result_b2[i] = accumulated_temp_b2[i];
                    if(accumulated_temp_b3[i] < 0) accumulated_temp_b3[i] = 0;
                    //else relu_result_b3[i] = accumulated_temp_b3[i];
                end

                accumulated_result_b0 = (accumulated_temp_b0[0] + accumulated_temp_b0[1] + accumulated_temp_b0[2] + accumulated_temp_b0[3]) >> 2;
                accumulated_result_b1 = (accumulated_temp_b1[0] + accumulated_temp_b1[1] + accumulated_temp_b1[2] + accumulated_temp_b1[3]) >> 2;
                accumulated_result_b2 = (accumulated_temp_b2[0] + accumulated_temp_b2[1] + accumulated_temp_b2[2] + accumulated_temp_b2[3]) >> 2;
                accumulated_result_b3 = (accumulated_temp_b3[0] + accumulated_temp_b3[1] + accumulated_temp_b3[2] + accumulated_temp_b3[3]) >> 2;

                quantized_result_b0 = (accumulated_result_b0 + 21'd64) >>> 7;
                if(quantized_result_b0 > 2047) quantized_result_b0 = 2047;
                else if(quantized_result_b0 < -2048) quantized_result_b0 = -2048;

                quantized_result_b1 = (accumulated_result_b1 + 21'd64) >>> 7;
                if(quantized_result_b1 > 2047) quantized_result_b1 = 2047;
                else if(quantized_result_b1 < -2048) quantized_result_b1 = -2048;

                quantized_result_b2 = (accumulated_result_b2 + 21'd64) >>> 7;
                if(quantized_result_b2 > 2047) quantized_result_b2 = 2047;
                else if(quantized_result_b2 < -2048) quantized_result_b2 = -2048;

                quantized_result_b3 = (accumulated_result_b3 + 21'd64) >>> 7;
                if(quantized_result_b3 > 2047) quantized_result_b3 = 2047;
                else if(quantized_result_b3 < -2048) quantized_result_b3 = -2048;

                if(quantized_result_b0[11:0] == 12'sd886) begin
                    for(j=0;j<4;j=j+1) begin
                            //$display("ACCU1 : %3d",accumulated_temp_b0[j]);
                    end
                end

                //if(quantized_result_b3[11:0] == 12'sd693) $display("%5d : %5d",cnt,quantized_result_b3[11:0]); //cnt = 326
                n_sram_wdata_b = {quantized_result_b0[11:0],quantized_result_b1[11:0],quantized_result_b2[11:0],quantized_result_b3[11:0],
                                  quantized_result_b0[11:0],quantized_result_b1[11:0],quantized_result_b2[11:0],quantized_result_b3[11:0],
                                  quantized_result_b0[11:0],quantized_result_b1[11:0],quantized_result_b2[11:0],quantized_result_b3[11:0],
                                  quantized_result_b0[11:0],quantized_result_b1[11:0],quantized_result_b2[11:0],quantized_result_b3[11:0]};
                case (1)
                    ((cnt-3)%48) == 11: n_sram_wen_b0 = 0;
                    ((cnt-3)%48) == 23: n_sram_wen_b1 = 0;
                    ((cnt-3)%48) == 35: n_sram_wen_b2 = 0;
                    ((cnt-3)%48) == 47: n_sram_wen_b3 = 0;
                    default: begin
                    end 
                endcase
            end
        end
        default: begin
            n_sram_wordmask_b = 16'b1111_1111_1111_1111;
            n_sram_raddr_b0 = 0;
            n_sram_raddr_b1 = 0;
            n_sram_raddr_b2 = 0;
            n_sram_raddr_b3 = 0;
            n_sram_waddr_b = 0;
            n_sram_wdata_b = 0;
            n_sram_wen_b0 = 1;
            n_sram_wen_b1 = 1;
            n_sram_wen_b2 = 1;
            n_sram_wen_b3 = 1;
            for(i=0; i<16; i=i+1) begin
                n_feature_map0_pw[i] = feature_map0_pw[i];
                n_feature_map1_pw[i] = feature_map1_pw[i];
                n_feature_map2_pw[i] = feature_map2_pw[i];
                n_feature_map3_pw[i] = feature_map3_pw[i];
            end
        end
    endcase
end
//weight
always @* begin
    for(i=0; i<54; i=i+1) begin
        n_weight0_dw[i] = weight0_dw[i];
        n_weight1_dw[i] = weight1_dw[i];
        n_weight2_dw[i] = weight2_dw[i];
        n_weight3_dw[i] = weight3_dw[i];
    end
    for(i=0; i<48; i=i+1) begin
        n_weight_pw[i] = weight_pw[i];
    end
    case (state) //synopys parallel_case
        IDLE: begin
            n_sram_raddr_weight = sram_raddr_weight;
        end
        PREP: begin
            n_sram_raddr_weight = sram_raddr_weight + 1;
            case (sram_raddr_weight) //synopys parallel_case
                1: begin
                    n_weight0_dw[0] = sram_rdata_weight[71:64];
                    n_weight0_dw[1] = sram_rdata_weight[63:56];
                    n_weight0_dw[2] = sram_rdata_weight[55:48];
                    n_weight0_dw[3] = sram_rdata_weight[47:40];
                    n_weight0_dw[4] = sram_rdata_weight[39:32];
                    n_weight0_dw[5] = sram_rdata_weight[31:24];
                    n_weight0_dw[6] = sram_rdata_weight[23:16];
                    n_weight0_dw[7] = sram_rdata_weight[15:8];
                    n_weight0_dw[8] = sram_rdata_weight[7:0];
                end
                2: begin
                    n_weight1_dw[0] = sram_rdata_weight[71:64];
                    n_weight1_dw[1] = sram_rdata_weight[63:56];
                    n_weight1_dw[2] = sram_rdata_weight[55:48];
                    n_weight1_dw[3] = sram_rdata_weight[47:40];
                    n_weight1_dw[4] = sram_rdata_weight[39:32];
                    n_weight1_dw[5] = sram_rdata_weight[31:24];
                    n_weight1_dw[6] = sram_rdata_weight[23:16];
                    n_weight1_dw[7] = sram_rdata_weight[15:8];
                    n_weight1_dw[8] = sram_rdata_weight[7:0];
                end
                3: begin
                    n_weight2_dw[0] = sram_rdata_weight[71:64];
                    n_weight2_dw[1] = sram_rdata_weight[63:56];
                    n_weight2_dw[2] = sram_rdata_weight[55:48];
                    n_weight2_dw[3] = sram_rdata_weight[47:40];
                    n_weight2_dw[4] = sram_rdata_weight[39:32];
                    n_weight2_dw[5] = sram_rdata_weight[31:24];
                    n_weight2_dw[6] = sram_rdata_weight[23:16];
                    n_weight2_dw[7] = sram_rdata_weight[15:8];
                    n_weight2_dw[8] = sram_rdata_weight[7:0];
                end
                4: begin
                    n_weight3_dw[0] = sram_rdata_weight[71:64];
                    n_weight3_dw[1] = sram_rdata_weight[63:56];
                    n_weight3_dw[2] = sram_rdata_weight[55:48];
                    n_weight3_dw[3] = sram_rdata_weight[47:40];
                    n_weight3_dw[4] = sram_rdata_weight[39:32];
                    n_weight3_dw[5] = sram_rdata_weight[31:24];
                    n_weight3_dw[6] = sram_rdata_weight[23:16];
                    n_weight3_dw[7] = sram_rdata_weight[15:8];
                    n_weight3_dw[8] = sram_rdata_weight[7:0];
                    n_sram_raddr_weight = sram_rdata_weight;
                end
                default: begin
                    for(i=0; i<9; i=i+1) begin
                        n_weight0_dw[i] = weight0_dw[i];
                        n_weight1_dw[i] = weight1_dw[i];
                        n_weight2_dw[i] = weight2_dw[i];
                        n_weight3_dw[i] = weight3_dw[i];
                    end
                end
            endcase
        end 
        CONV1_dw: begin
            n_sram_raddr_weight = sram_raddr_weight + 1;
            if(sram_raddr_weight == 7) n_sram_raddr_weight = sram_raddr_weight;
            //if(cnt == 155) n_sram_raddr_weight = 6;
            if(cnt == 38) n_sram_raddr_weight = 6;
            case (sram_raddr_weight)//synopys parallel_case
                5: begin
                    {n_weight_pw[0],n_weight_pw[1],n_weight_pw[2],n_weight_pw[3],n_weight_pw[4],
                    n_weight_pw[5],n_weight_pw[6],n_weight_pw[7],n_weight_pw[8]} = sram_rdata_weight;
                    //$display("sram_rdata_weight0 : %b",sram_rdata_weight);
                end 
                6: begin
                    {n_weight_pw[9],n_weight_pw[10],n_weight_pw[11],n_weight_pw[12],
                    n_weight_pw[13],n_weight_pw[14],n_weight_pw[15]} = sram_rdata_weight[71:16];
                    //$display("sram_rdata_weight1 : %b",sram_rdata_weight);
                end
                default: begin
                    for(i=0; i<48; i=i+1) begin
                        n_weight_pw[i] = weight_pw[i];
                    end
                end 
            endcase
            
            /*
            $display("weight0_dw : ");
            for(i=0; i<9; i=i+1) begin
                $write("[%b %3d/-%3d]",weight0_dw[i][7],weight0_dw[i][6:0],128-weight0_dw[i][6:0]);
                if(i%3==2) $display("");
            
            end

            
            $display("");
            $display("weight1_dw : ");
            for(i=0; i<9; i=i+1) begin
                $write("%3d ",weight1_dw[i]);
                if(i%3==2) $display("");
            end
            $display("");
            $display("weight2_dw : ");
            for(i=0; i<9; i=i+1) begin
                $write("[%b %3d/-%3d]",weight2_dw[i][7],weight2_dw[i][6:0],128-weight2_dw[i][6:0]);
                if(i%3==2) $display("");
            end
            $display("");
            $display("weight3_dw : ");
            for(i=0; i<9; i=i+1) begin
                $write("[%b %3d/-%3d]",weight3_dw[i][7],weight3_dw[i][6:0],128-weight3_dw[i][6:0]);
                if(i%3==2) $display("");
            end
            $display("");
            */
            
        end
        CONV1_pw: begin
            n_sram_raddr_weight = sram_raddr_weight + 1;
            if(sram_raddr_weight == 11) n_sram_raddr_weight = sram_raddr_weight;
            if(cnt == 38) n_sram_raddr_weight = 10;
            case (sram_raddr_weight)//synopys parallel_case
                7: begin
                    {n_weight0_dw[0],n_weight0_dw[1],n_weight0_dw[2],n_weight0_dw[3],n_weight0_dw[4]
                    ,n_weight0_dw[5],n_weight0_dw[6],n_weight0_dw[7],n_weight0_dw[8]} = sram_rdata_weight;
                end
                8: begin
                    {n_weight1_dw[0],n_weight1_dw[1],n_weight1_dw[2],n_weight1_dw[3],n_weight1_dw[4]
                    ,n_weight1_dw[5],n_weight1_dw[6],n_weight1_dw[7],n_weight1_dw[8]} = sram_rdata_weight;
                end
                9: begin
                    {n_weight2_dw[0],n_weight2_dw[1],n_weight2_dw[2],n_weight2_dw[3],n_weight2_dw[4]
                    ,n_weight2_dw[5],n_weight2_dw[6],n_weight2_dw[7],n_weight2_dw[8]} = sram_rdata_weight;
                end
                10: begin
                    {n_weight3_dw[0],n_weight3_dw[1],n_weight3_dw[2],n_weight3_dw[3],n_weight3_dw[4]
                    ,n_weight3_dw[5],n_weight3_dw[6],n_weight3_dw[7],n_weight3_dw[8]} = sram_rdata_weight;
                end
                default: begin
                    for(i=0; i<9; i=i+1) begin
                        n_weight0_dw[i] = weight0_dw[i];
                        n_weight1_dw[i] = weight1_dw[i];
                        n_weight2_dw[i] = weight2_dw[i];
                        n_weight3_dw[i] = weight3_dw[i];
                    end
                end
            endcase          
        end
        CONV2_dw: begin
            n_sram_raddr_weight = sram_raddr_weight + 1;
            if(sram_raddr_weight == 17) n_sram_raddr_weight = sram_raddr_weight;
            if(cnt == 38) n_sram_raddr_weight = 16;
            case (sram_raddr_weight)//synopys parallel_case
                11: begin
                    {n_weight_pw[0],n_weight_pw[1],n_weight_pw[2],n_weight_pw[3],n_weight_pw[4],
                    n_weight_pw[5],n_weight_pw[6],n_weight_pw[7],n_weight_pw[8]} = sram_rdata_weight;
                    //$display("sram_rdata_weight0 : %b",sram_rdata_weight);
                end 
                12: begin
                    {n_weight_pw[9],n_weight_pw[10],n_weight_pw[11],n_weight_pw[12],
                    n_weight_pw[13],n_weight_pw[14],n_weight_pw[15]} = sram_rdata_weight[71:16];
                    //$display("sram_rdata_weight1 : %b",sram_rdata_weight);
                end
                13: begin
                    {n_weight_pw[16],n_weight_pw[17],n_weight_pw[18],n_weight_pw[19],n_weight_pw[20],
                    n_weight_pw[21],n_weight_pw[22],n_weight_pw[23],n_weight_pw[24]} = sram_rdata_weight;
                    //$display("sram_rdata_weight0 : %b",sram_rdata_weight);
                end 
                14: begin
                    {n_weight_pw[25],n_weight_pw[26],n_weight_pw[27],n_weight_pw[28],
                    n_weight_pw[29],n_weight_pw[30],n_weight_pw[31]} = sram_rdata_weight[71:16];
                    //$display("sram_rdata_weight1 : %b",sram_rdata_weight);
                end
                15: begin
                    {n_weight_pw[32],n_weight_pw[33],n_weight_pw[34],n_weight_pw[35],n_weight_pw[36],
                    n_weight_pw[37],n_weight_pw[38],n_weight_pw[39],n_weight_pw[40]} = sram_rdata_weight;
                    //$display("sram_rdata_weight0 : %b",sram_rdata_weight);
                end 
                16: begin
                    {n_weight_pw[41],n_weight_pw[42],n_weight_pw[43],n_weight_pw[44],
                    n_weight_pw[45],n_weight_pw[46],n_weight_pw[47]} = sram_rdata_weight[71:16];
                    //$display("sram_rdata_weight1 : %b",sram_rdata_weight);
                end
                default: begin
                    for(i=0; i<48; i=i+1) begin
                        n_weight_pw[i] = weight_pw[i];
                    end
                end 
            endcase
        end
        CONV2_pw: begin
            n_sram_raddr_weight = sram_raddr_weight + 1;
            if(sram_raddr_weight == 41) n_sram_raddr_weight = sram_raddr_weight;
            if(cnt == 111) n_sram_raddr_weight = 40;
            case (sram_raddr_weight)//synopys parallel_case
                17: begin
                    {n_weight0_dw[0],n_weight0_dw[1],n_weight0_dw[2],n_weight0_dw[3],n_weight0_dw[4]
                    ,n_weight0_dw[5],n_weight0_dw[6],n_weight0_dw[7],n_weight0_dw[8]} = sram_rdata_weight;
                end
                18: begin
                    {n_weight1_dw[0],n_weight1_dw[1],n_weight1_dw[2],n_weight1_dw[3],n_weight1_dw[4]
                    ,n_weight1_dw[5],n_weight1_dw[6],n_weight1_dw[7],n_weight1_dw[8]} = sram_rdata_weight;
                end
                19: begin
                    {n_weight2_dw[0],n_weight2_dw[1],n_weight2_dw[2],n_weight2_dw[3],n_weight2_dw[4]
                    ,n_weight2_dw[5],n_weight2_dw[6],n_weight2_dw[7],n_weight2_dw[8]} = sram_rdata_weight;
                end
                20: begin
                    {n_weight3_dw[0],n_weight3_dw[1],n_weight3_dw[2],n_weight3_dw[3],n_weight3_dw[4]
                    ,n_weight3_dw[5],n_weight3_dw[6],n_weight3_dw[7],n_weight3_dw[8]} = sram_rdata_weight;
                end
                21: begin
                    {n_weight0_dw[9],n_weight0_dw[10],n_weight0_dw[11],n_weight0_dw[12],n_weight0_dw[13]
                    ,n_weight0_dw[14],n_weight0_dw[15],n_weight0_dw[16],n_weight0_dw[17]} = sram_rdata_weight;
                end
                22: begin
                    {n_weight1_dw[9],n_weight1_dw[10],n_weight1_dw[11],n_weight1_dw[12],n_weight1_dw[13]
                    ,n_weight1_dw[14],n_weight1_dw[15],n_weight1_dw[16],n_weight1_dw[17]} = sram_rdata_weight;
                end
                23: begin
                    {n_weight2_dw[9],n_weight2_dw[10],n_weight2_dw[11],n_weight2_dw[12],n_weight2_dw[13]
                    ,n_weight2_dw[14],n_weight2_dw[15],n_weight2_dw[16],n_weight2_dw[17]} = sram_rdata_weight;
                end
                24: begin
                    {n_weight3_dw[9],n_weight3_dw[10],n_weight3_dw[11],n_weight3_dw[12],n_weight3_dw[13]
                    ,n_weight3_dw[14],n_weight3_dw[15],n_weight3_dw[16],n_weight3_dw[17]} = sram_rdata_weight;
                end
                25: begin
                    {n_weight0_dw[18],n_weight0_dw[19],n_weight0_dw[20],n_weight0_dw[21],n_weight0_dw[22]
                    ,n_weight0_dw[23],n_weight0_dw[24],n_weight0_dw[25],n_weight0_dw[26]} = sram_rdata_weight;
                end
                26: begin
                    {n_weight1_dw[18],n_weight1_dw[19],n_weight1_dw[20],n_weight1_dw[21],n_weight1_dw[22]
                    ,n_weight1_dw[23],n_weight1_dw[24],n_weight1_dw[25],n_weight1_dw[26]} = sram_rdata_weight;
                end
                27: begin
                    {n_weight2_dw[18],n_weight2_dw[19],n_weight2_dw[20],n_weight2_dw[21],n_weight2_dw[22]
                    ,n_weight2_dw[23],n_weight2_dw[24],n_weight2_dw[25],n_weight2_dw[26]} = sram_rdata_weight;
                end
                28: begin
                    {n_weight3_dw[18],n_weight3_dw[19],n_weight3_dw[20],n_weight3_dw[21],n_weight3_dw[22]
                    ,n_weight3_dw[23],n_weight3_dw[24],n_weight3_dw[25],n_weight3_dw[26]} = sram_rdata_weight;
                end
                //==========================================================================================//
                29: begin
                    {n_weight0_dw[27],n_weight0_dw[28],n_weight0_dw[29],n_weight0_dw[30],n_weight0_dw[31]
                    ,n_weight0_dw[32],n_weight0_dw[33],n_weight0_dw[34],n_weight0_dw[35]} = sram_rdata_weight;
                end
                30: begin
                    {n_weight1_dw[27],n_weight1_dw[28],n_weight1_dw[29],n_weight1_dw[30],n_weight1_dw[31]
                    ,n_weight1_dw[32],n_weight1_dw[33],n_weight1_dw[34],n_weight1_dw[35]} = sram_rdata_weight;
                end
                31: begin
                    {n_weight2_dw[27],n_weight2_dw[28],n_weight2_dw[29],n_weight2_dw[30],n_weight2_dw[31]
                    ,n_weight2_dw[32],n_weight2_dw[33],n_weight2_dw[34],n_weight2_dw[35]} = sram_rdata_weight;
                end
                32: begin
                    {n_weight3_dw[27],n_weight3_dw[28],n_weight3_dw[29],n_weight3_dw[30],n_weight3_dw[31]
                    ,n_weight3_dw[32],n_weight3_dw[33],n_weight3_dw[34],n_weight3_dw[35]} = sram_rdata_weight;
                end
                33: begin
                    {n_weight0_dw[36],n_weight0_dw[37],n_weight0_dw[38],n_weight0_dw[39],n_weight0_dw[40]
                    ,n_weight0_dw[41],n_weight0_dw[42],n_weight0_dw[43],n_weight0_dw[44]} = sram_rdata_weight;
                end
                34: begin
                    {n_weight1_dw[36],n_weight1_dw[37],n_weight1_dw[38],n_weight1_dw[39],n_weight1_dw[40]
                    ,n_weight1_dw[41],n_weight1_dw[42],n_weight1_dw[43],n_weight1_dw[44]} = sram_rdata_weight;
                end
                35: begin
                    {n_weight2_dw[36],n_weight2_dw[37],n_weight2_dw[38],n_weight2_dw[39],n_weight2_dw[40]
                    ,n_weight2_dw[41],n_weight2_dw[42],n_weight2_dw[43],n_weight2_dw[44]} = sram_rdata_weight;
                end
                36: begin
                    {n_weight3_dw[36],n_weight3_dw[37],n_weight3_dw[38],n_weight3_dw[39],n_weight3_dw[40]
                    ,n_weight3_dw[41],n_weight3_dw[42],n_weight3_dw[43],n_weight3_dw[44]} = sram_rdata_weight;
                end
                37: begin
                    {n_weight0_dw[45],n_weight0_dw[46],n_weight0_dw[47],n_weight0_dw[48],n_weight0_dw[49]
                    ,n_weight0_dw[50],n_weight0_dw[51],n_weight0_dw[52],n_weight0_dw[53]} = sram_rdata_weight;
                end
                38: begin
                    {n_weight1_dw[45],n_weight1_dw[46],n_weight1_dw[47],n_weight1_dw[48],n_weight1_dw[49]
                    ,n_weight1_dw[50],n_weight1_dw[51],n_weight1_dw[52],n_weight1_dw[53]} = sram_rdata_weight;
                end
                39: begin
                    {n_weight2_dw[45],n_weight2_dw[46],n_weight2_dw[47],n_weight2_dw[48],n_weight2_dw[49]
                    ,n_weight2_dw[50],n_weight2_dw[51],n_weight2_dw[52],n_weight2_dw[53]} = sram_rdata_weight;
                end
                40: begin
                    {n_weight3_dw[45],n_weight3_dw[46],n_weight3_dw[47],n_weight3_dw[48],n_weight3_dw[49]
                    ,n_weight3_dw[50],n_weight3_dw[51],n_weight3_dw[52],n_weight3_dw[53]} = sram_rdata_weight;
                end
                default: begin
                    for(i=0; i<54; i=i+1) begin
                        n_weight0_dw[i] = weight0_dw[i];
                        n_weight1_dw[i] = weight1_dw[i];
                        n_weight2_dw[i] = weight2_dw[i];
                        n_weight3_dw[i] = weight3_dw[i];
                    end
                end
            endcase
        end
        CONV3_pl: begin
            for(i=0; i<54; i=i+1) begin
                n_weight0_dw[i] = weight0_dw[i];
                n_weight1_dw[i] = weight1_dw[i];
                n_weight2_dw[i] = weight2_dw[i];
                n_weight3_dw[i] = weight3_dw[i];
            end
            if((cnt-4)%48 < 12 & cnt > 51 & sram_raddr_weight < 784) begin
                //if(cnt < 220)$display("%3d(%4d) : %b_%b_%b",((sram_raddr_weight-17)%24),cnt,sram_rdata_weight[71:64],
                //sram_rdata_weight[63:56],sram_rdata_weight[55:48]);
                n_sram_raddr_weight = sram_raddr_weight + 1;
                case (((sram_raddr_weight-17)%24))//synopys parallel_case
                0: begin
                    {n_weight0_dw[0],n_weight0_dw[1],n_weight0_dw[2],n_weight0_dw[3],n_weight0_dw[4]
                    ,n_weight0_dw[5],n_weight0_dw[6],n_weight0_dw[7],n_weight0_dw[8]} = sram_rdata_weight;
                end
                1: begin
                    {n_weight1_dw[0],n_weight1_dw[1],n_weight1_dw[2],n_weight1_dw[3],n_weight1_dw[4]
                    ,n_weight1_dw[5],n_weight1_dw[6],n_weight1_dw[7],n_weight1_dw[8]} = sram_rdata_weight;
                end
                2: begin
                    {n_weight2_dw[0],n_weight2_dw[1],n_weight2_dw[2],n_weight2_dw[3],n_weight2_dw[4]
                    ,n_weight2_dw[5],n_weight2_dw[6],n_weight2_dw[7],n_weight2_dw[8]} = sram_rdata_weight;
                end
                3: begin
                    {n_weight3_dw[0],n_weight3_dw[1],n_weight3_dw[2],n_weight3_dw[3],n_weight3_dw[4]
                    ,n_weight3_dw[5],n_weight3_dw[6],n_weight3_dw[7],n_weight3_dw[8]} = sram_rdata_weight;
                end
                4: begin
                    {n_weight0_dw[9],n_weight0_dw[10],n_weight0_dw[11],n_weight0_dw[12],n_weight0_dw[13]
                    ,n_weight0_dw[14],n_weight0_dw[15],n_weight0_dw[16],n_weight0_dw[17]} = sram_rdata_weight;
                end
                5: begin
                    {n_weight1_dw[9],n_weight1_dw[10],n_weight1_dw[11],n_weight1_dw[12],n_weight1_dw[13]
                    ,n_weight1_dw[14],n_weight1_dw[15],n_weight1_dw[16],n_weight1_dw[17]} = sram_rdata_weight;
                end
                6: begin
                    {n_weight2_dw[9],n_weight2_dw[10],n_weight2_dw[11],n_weight2_dw[12],n_weight2_dw[13]
                    ,n_weight2_dw[14],n_weight2_dw[15],n_weight2_dw[16],n_weight2_dw[17]} = sram_rdata_weight;
                end
                7: begin
                    {n_weight3_dw[9],n_weight3_dw[10],n_weight3_dw[11],n_weight3_dw[12],n_weight3_dw[13]
                    ,n_weight3_dw[14],n_weight3_dw[15],n_weight3_dw[16],n_weight3_dw[17]} = sram_rdata_weight;
                end
                8: begin
                    {n_weight0_dw[18],n_weight0_dw[19],n_weight0_dw[20],n_weight0_dw[21],n_weight0_dw[22]
                    ,n_weight0_dw[23],n_weight0_dw[24],n_weight0_dw[25],n_weight0_dw[26]} = sram_rdata_weight;
                end
                9: begin
                    {n_weight1_dw[18],n_weight1_dw[19],n_weight1_dw[20],n_weight1_dw[21],n_weight1_dw[22]
                    ,n_weight1_dw[23],n_weight1_dw[24],n_weight1_dw[25],n_weight1_dw[26]} = sram_rdata_weight;
                end
                10: begin
                    {n_weight2_dw[18],n_weight2_dw[19],n_weight2_dw[20],n_weight2_dw[21],n_weight2_dw[22]
                    ,n_weight2_dw[23],n_weight2_dw[24],n_weight2_dw[25],n_weight2_dw[26]} = sram_rdata_weight;
                end
                11: begin
                    //{n_weight3_dw[18],n_weight3_dw[19],n_weight3_dw[20],n_weight3_dw[21],n_weight3_dw[22]
                    //,n_weight3_dw[23],n_weight3_dw[24],n_weight3_dw[25],n_weight3_dw[26]} = sram_rdata_weight;
                end
                //==========================================================================================//
                12: begin
                    {n_weight0_dw[27],n_weight0_dw[28],n_weight0_dw[29],n_weight0_dw[30],n_weight0_dw[31]
                    ,n_weight0_dw[32],n_weight0_dw[33],n_weight0_dw[34],n_weight0_dw[35]} = sram_rdata_weight;
                end
                13: begin
                    {n_weight1_dw[27],n_weight1_dw[28],n_weight1_dw[29],n_weight1_dw[30],n_weight1_dw[31]
                    ,n_weight1_dw[32],n_weight1_dw[33],n_weight1_dw[34],n_weight1_dw[35]} = sram_rdata_weight;
                end
                14: begin
                    {n_weight2_dw[27],n_weight2_dw[28],n_weight2_dw[29],n_weight2_dw[30],n_weight2_dw[31]
                    ,n_weight2_dw[32],n_weight2_dw[33],n_weight2_dw[34],n_weight2_dw[35]} = sram_rdata_weight;
                end
                15: begin
                    {n_weight3_dw[27],n_weight3_dw[28],n_weight3_dw[29],n_weight3_dw[30],n_weight3_dw[31]
                    ,n_weight3_dw[32],n_weight3_dw[33],n_weight3_dw[34],n_weight3_dw[35]} = sram_rdata_weight;
                end
                16: begin
                    {n_weight0_dw[36],n_weight0_dw[37],n_weight0_dw[38],n_weight0_dw[39],n_weight0_dw[40]
                    ,n_weight0_dw[41],n_weight0_dw[42],n_weight0_dw[43],n_weight0_dw[44]} = sram_rdata_weight;
                end
                17: begin
                    {n_weight1_dw[36],n_weight1_dw[37],n_weight1_dw[38],n_weight1_dw[39],n_weight1_dw[40]
                    ,n_weight1_dw[41],n_weight1_dw[42],n_weight1_dw[43],n_weight1_dw[44]} = sram_rdata_weight;
                end
                18: begin
                    {n_weight2_dw[36],n_weight2_dw[37],n_weight2_dw[38],n_weight2_dw[39],n_weight2_dw[40]
                    ,n_weight2_dw[41],n_weight2_dw[42],n_weight2_dw[43],n_weight2_dw[44]} = sram_rdata_weight;
                end
                19: begin
                    {n_weight3_dw[36],n_weight3_dw[37],n_weight3_dw[38],n_weight3_dw[39],n_weight3_dw[40]
                    ,n_weight3_dw[41],n_weight3_dw[42],n_weight3_dw[43],n_weight3_dw[44]} = sram_rdata_weight;
                end
                20: begin
                    {n_weight0_dw[45],n_weight0_dw[46],n_weight0_dw[47],n_weight0_dw[48],n_weight0_dw[49]
                    ,n_weight0_dw[50],n_weight0_dw[51],n_weight0_dw[52],n_weight0_dw[53]} = sram_rdata_weight;
                end
                21: begin
                    {n_weight1_dw[45],n_weight1_dw[46],n_weight1_dw[47],n_weight1_dw[48],n_weight1_dw[49]
                    ,n_weight1_dw[50],n_weight1_dw[51],n_weight1_dw[52],n_weight1_dw[53]} = sram_rdata_weight;
                end
                22: begin
                    {n_weight2_dw[45],n_weight2_dw[46],n_weight2_dw[47],n_weight2_dw[48],n_weight2_dw[49]
                    ,n_weight2_dw[50],n_weight2_dw[51],n_weight2_dw[52],n_weight2_dw[53]} = sram_rdata_weight;
                end
                23: begin
                    //if(sram_raddr_weight > 40) 
                    //{n_weight3_dw[45],n_weight3_dw[46],n_weight3_dw[47],n_weight3_dw[48],n_weight3_dw[49]
                    //,n_weight3_dw[50],n_weight3_dw[51],n_weight3_dw[52],n_weight3_dw[53]} = sram_rdata_weight;
                end
                default: begin
                end
            endcase
            end 
            else if((cnt-4)%48 == 12 & cnt > 51 & sram_raddr_weight < 784) begin
                n_sram_raddr_weight = sram_raddr_weight;
                case (((sram_raddr_weight-17)%24))//synopys parallel_case
                    11: begin
                        {n_weight3_dw[18],n_weight3_dw[19],n_weight3_dw[20],n_weight3_dw[21],n_weight3_dw[22]
                        ,n_weight3_dw[23],n_weight3_dw[24],n_weight3_dw[25],n_weight3_dw[26]} = sram_rdata_weight;
                    end
                    23: begin
                        if(sram_raddr_weight > 40) 
                        {n_weight3_dw[45],n_weight3_dw[46],n_weight3_dw[47],n_weight3_dw[48],n_weight3_dw[49]
                        ,n_weight3_dw[50],n_weight3_dw[51],n_weight3_dw[52],n_weight3_dw[53]} = sram_rdata_weight;
                    end
                default: begin
                end
                endcase
            end
            else if((cnt-3)%48 == 46 & cnt > 51) n_sram_raddr_weight = sram_raddr_weight - 1;
            else if((cnt-3)%48 == 47 & cnt > 51) n_sram_raddr_weight = sram_raddr_weight + 1;
            else n_sram_raddr_weight = sram_raddr_weight;         
/*
            //if(sram_raddr_weight == 52) begin
            //if((cnt-2)%48 == 0) begin
            if(cnt == 114) begin
                //if(cnt == 80) begin
                $display("weight00_dw : (%3d)",cnt);
                for(i=0; i<9; i=i+1) begin
                    $write("%b_",weight0_dw[i]);
                    if(i%3==2) $display("");
                end
                $display("weight01_dw : (%3d)",cnt);
                for(i=0; i<9; i=i+1) begin
                    $write("%b_",weight0_dw[i+9]);
                    if(i%3==2) $display("");
                end
                $display("weight02_dw : (%3d)",cnt);
                for(i=0; i<9; i=i+1) begin
                    //$write("[%4d]",$signed(weight3_dw[i+18]));
                    //$write("[%b %3d/-%3d]",weight0_dw[i+9][7],weight0_dw[i+9][6:0],128-weight0_dw[i+9][6:0]);
                    $write("%b_",weight0_dw[i+18]);
                    if(i%3==2) $display("");
                end             
            end
            //$display("weight_addr : %3d (%3d)",sram_raddr_weight,cnt);
*/
        end
        default: begin
            n_sram_raddr_weight = sram_raddr_weight;
        end 
    endcase
end
//bias
always @* begin
    for(i=0; i<4; i=i+1)begin
        n_bias_dw[i] = bias_dw[i];
    end
    for(i=0; i<12; i=i+1) begin
        n_bias_pw[i] = bias_pw[i];
    end
    case (state) //synopys parallel_case
        IDLE: begin
            n_sram_raddr_bias = sram_raddr_bias;
        end
        PREP: begin
            n_sram_raddr_bias = sram_raddr_bias + 1;
            case (sram_raddr_bias)
                1: begin
                    n_bias_dw[0] = sram_rdata_bias;
                end
                2: begin
                    n_bias_dw[1] = sram_rdata_bias;
                end
                3: begin
                    n_bias_dw[2] = sram_rdata_bias;
                end
                4: begin
                    n_bias_dw[3] = sram_rdata_bias;
                end
                default: begin
                    for(i=0; i<4; i=i+1)begin
                        n_bias_dw[i] = bias_dw[i];
                    end
                end
            endcase
            //if(sram_raddr_bias == 4) n_sram_raddr_bias = sram_raddr_bias;
            //if(sram_raddr_bias > 0) n_bias_dw[sram_raddr_bias-1] = sram_rdata_bias;
        end  
        CONV1_dw: begin
            n_sram_raddr_bias = sram_raddr_bias + 1;
            if(sram_raddr_bias == 9) n_sram_raddr_bias = sram_raddr_bias;
            if(cnt == 38) n_sram_raddr_bias = 8;
            case (sram_raddr_bias)
                5: begin
                    n_bias_pw[0] = sram_rdata_bias;
                end 
                6: begin
                    n_bias_pw[1] = sram_rdata_bias;
                end
                7: begin
                    n_bias_pw[2] = sram_rdata_bias;
                end
                8: begin
                    n_bias_pw[3] = sram_rdata_bias;
                end
                default: begin
                    for(i=0; i<12; i=i+1)begin
                        n_bias_pw[i] = bias_pw[i];
                    end
                end
            endcase
        end
        CONV1_pw: begin
            n_sram_raddr_bias = sram_raddr_bias + 1;
            if(sram_raddr_bias == 13) n_sram_raddr_bias = sram_raddr_bias;
            //if(cnt == 155) n_sram_raddr_bias = 12;
            if(cnt == 38) n_sram_raddr_bias = 12;
            case (sram_raddr_bias)
                9: begin
                    n_bias_dw[0] = sram_rdata_bias;
                end
                10: begin
                    n_bias_dw[1] = sram_rdata_bias;
                end
                11: begin
                    n_bias_dw[2] = sram_rdata_bias;
                end
                12: begin
                    n_bias_dw[3] = sram_rdata_bias;
                end
                default: begin
                    for(i=0; i<4; i=i+1)begin
                        n_bias_dw[i] = bias_dw[i];
                    end
                end
            endcase
        end
        CONV2_dw: begin
            n_sram_raddr_bias = sram_raddr_bias + 1;
            if(sram_raddr_bias == 25) n_sram_raddr_bias = sram_raddr_bias;
            if(cnt == 38) n_sram_raddr_bias = 24;
            case (sram_raddr_bias)
                13: begin
                    n_bias_pw[0] = sram_rdata_bias;
                end 
                14: begin
                    n_bias_pw[1] = sram_rdata_bias;
                end
                15: begin
                    n_bias_pw[2] = sram_rdata_bias;
                end
                16: begin
                    n_bias_pw[3] = sram_rdata_bias;
                end
                17: begin
                    n_bias_pw[4] = sram_rdata_bias;
                end 
                18: begin
                    n_bias_pw[5] = sram_rdata_bias;
                end
                19: begin
                    n_bias_pw[6] = sram_rdata_bias;
                end
                20: begin
                    n_bias_pw[7] = sram_rdata_bias;
                end
                21: begin
                    n_bias_pw[8] = sram_rdata_bias;
                end 
                22: begin
                    n_bias_pw[9] = sram_rdata_bias;
                end
                23: begin
                    n_bias_pw[10] = sram_rdata_bias;
                end
                24: begin
                    n_bias_pw[11] = sram_rdata_bias;
                end
                default: begin
                    for(i=0; i<12; i=i+1)begin
                        n_bias_pw[i] = bias_pw[i];
                    end
                end
            endcase
            /*
            $display("bias_dw : ");
            for(i=0; i<4; i=i+1)
            $write("[%b %3d/-%3d]",bias_dw[i][7],bias_dw[i][6:0],128-bias_dw[i][6:0]);
            $display("");
            */
        end
        CONV2_pw: begin
            n_sram_raddr_bias = sram_raddr_bias + 1;  
            if(sram_raddr_bias == 27) n_sram_raddr_bias = sram_raddr_bias;
            if(cnt == 111) n_sram_raddr_bias = 26;
            case (sram_raddr_bias) //synopys parallel_case
                25: begin
                    n_bias_dw[0] = sram_rdata_bias;
                end
                26: begin
                    n_bias_dw[1] = sram_rdata_bias;
                end
                default: begin
                    for(i=0; i<4; i=i+1)begin
                        n_bias_dw[i] = bias_dw[i];
                    end
                end
            endcase
/*
            n_sram_raddr_bias = sram_raddr_bias + 1;  
            if(sram_raddr_bias == 49) n_sram_raddr_bias = sram_raddr_bias;
            if(cnt == 111) n_sram_raddr_bias = 48;
            case (sram_raddr_bias) //synopys parallel_case
                25: begin
                    n_bias_dw[0] = sram_rdata_bias;
                end
                26: begin
                    n_bias_dw[1] = sram_rdata_bias;
                end
                27: begin
                    n_bias_dw[2] = sram_rdata_bias;
                end
                28: begin
                    n_bias_dw[3] = sram_rdata_bias;
                end
                29: begin
                    n_bias_dw[4] = sram_rdata_bias;
                end
                30: begin
                    n_bias_dw[5] = sram_rdata_bias;
                end
                31: begin
                    n_bias_dw[6] = sram_rdata_bias;
                end
                32: begin
                    n_bias_dw[7] = sram_rdata_bias;
                end
                33: begin
                    n_bias_dw[8] = sram_rdata_bias;
                end
                34: begin
                    n_bias_dw[9] = sram_rdata_bias;
                end
                35: begin
                    n_bias_dw[10] = sram_rdata_bias;
                end
                36: begin
                    n_bias_dw[11] = sram_rdata_bias;
                end
                //================================//
                37: begin
                    n_bias_dw[12] = sram_rdata_bias;
                end
                38: begin
                    n_bias_dw[13] = sram_rdata_bias;
                end
                39: begin
                    n_bias_dw[14] = sram_rdata_bias;
                end
                40: begin
                    n_bias_dw[15] = sram_rdata_bias;
                end
                41: begin
                    n_bias_dw[16] = sram_rdata_bias;
                end
                42: begin
                    n_bias_dw[17] = sram_rdata_bias;
                end
                43: begin
                    n_bias_dw[18] = sram_rdata_bias;
                end
                44: begin
                    n_bias_dw[19] = sram_rdata_bias;
                end
                45: begin
                    n_bias_dw[20] = sram_rdata_bias;
                end
                46: begin
                    n_bias_dw[21] = sram_rdata_bias;
                end
                47: begin
                    n_bias_dw[22] = sram_rdata_bias;
                end
                48: begin
                    n_bias_dw[23] = sram_rdata_bias;
                end
                default: begin
                    for(i=0; i<24; i=i+1)begin
                        n_bias_dw[i] = bias_dw[i];
                    end
                end
            endcase
*/
        end
        CONV3_pl: begin
            if((cnt-4)%48 == 0 & cnt > 51 & sram_raddr_bias < 88) begin
                n_sram_raddr_bias = sram_raddr_bias + 1;
                case ((sram_raddr_bias-26)%2) //synopys parallel_case
                    0: begin
                        n_bias_dw[0] = sram_rdata_bias;
                    end 
                    1: begin
                        n_bias_dw[1] = sram_rdata_bias;
                    end
                    default: begin
                    end
                endcase
            end
            else if((cnt-3)%48 == 46 & cnt > 51) n_sram_raddr_bias = sram_raddr_bias - 1;
            else if((cnt-3)%48 == 47 & cnt > 51) n_sram_raddr_bias = sram_raddr_bias + 1;
            else n_sram_raddr_bias = sram_raddr_bias;
            //$display("BIAS : [%3d]",bias_dw[i]);
/*            
            $display("bias_dw : ");
            for(i=0; i<12; i=i+1)
            $display("[%b]",bias_dw[i]);
            $display("");
*/            
        end
        default: begin
            n_sram_raddr_bias = sram_raddr_bias;
            /*
            for(i=0; i<4; i=i+1)begin
                n_bias_dw[i] = bias_dw[i];
            end
            for(i=0; i<12; i=i+1)begin
                n_bias_pw[i] = bias_pw[i];
            end
            */
        end 
    endcase
end
//DFF
always @(posedge clk) begin
    if(!srst_n) begin
        //===================================//
        //===================================//
        sram_raddr_a0 <= 0;
        sram_raddr_a1 <= 0;
        sram_raddr_a2 <= 0;
        sram_raddr_a3 <= 0;
        // read address to SRAM group B
        sram_raddr_b0 <= 0;
        sram_raddr_b1 <= 0;
        sram_raddr_b2 <= 0;
        sram_raddr_b3 <= 0;
        // read address to parameter SRAM
        sram_raddr_weight <= 0;       
        sram_raddr_bias <= 0;         
        // write enable for SRAM groups A & B
        sram_wen_a0 <= 1;
        sram_wen_a1 <= 1;
        sram_wen_a2 <= 1;
        sram_wen_a3 <= 1;
        sram_wen_b0 <= 1;
        sram_wen_b1 <= 1;
        sram_wen_b2 <= 1;
        sram_wen_b3 <= 1;
        // word mask for SRAM groups A & B
        sram_wordmask_a <= 0;
        sram_wordmask_b <= 0;
        // write addrress to SRAM groups A & B
        sram_waddr_a <= 0;
        sram_waddr_b <= 0;
        // write data to SRAM groups A & B
        sram_wdata_a <= 0;
        sram_wdata_b <= 0;
        //===================================//
        //===================================//
        valid <= 0;
        state <= 0;
        cnt <= 0;
        // CONV1_dw
        for(i=0;i<36;i=i+1) begin
            map0[i] <= 0;
            map1[i] <= 0;
            map2[i] <= 0;
            map3[i] <= 0;
        end
        for(i=0; i<54; i=i+1) begin
            weight0_dw[i] <= 0;
            weight1_dw[i] <= 0;
            weight2_dw[i] <= 0;
            weight3_dw[i] <= 0;
        end
        for(i=0; i<4; i=i+1) begin
            bias_dw[i] <= 0;
        end
        // CONV1_pw
        for(i=0; i<16; i=i+1) begin
            feature_map0_pw[i] <= 0;
            feature_map1_pw[i] <= 0;
            feature_map2_pw[i] <= 0;
            feature_map3_pw[i] <= 0;
        end
        for(i=0; i<48; i=i+1) begin
            weight_pw[i] <= 0;
        end
        for(i=0; i<12; i=i+1) begin
            bias_pw[i] <= 0;
        end
        for(i=0; i<4; i=i+1) begin
            convolved_temp_b0[i] <= 0;
            convolved_temp_b1[i] <= 0;
            convolved_temp_b2[i] <= 0;
            convolved_temp_b3[i] <= 0;
        end
    end
    else begin
        //===================================//
        //===================================//
        sram_raddr_a0 <= n_sram_raddr_a0;
        sram_raddr_a1 <= n_sram_raddr_a1;
        sram_raddr_a2 <= n_sram_raddr_a2;
        sram_raddr_a3 <= n_sram_raddr_a3;
        // read address to SRAM group B
        sram_raddr_b0 <= n_sram_raddr_b0;
        sram_raddr_b1 <= n_sram_raddr_b1;
        sram_raddr_b2 <= n_sram_raddr_b2;
        sram_raddr_b3 <= n_sram_raddr_b3;
        // read address to parameter SRAM
        sram_raddr_weight <= n_sram_raddr_weight;       
        sram_raddr_bias <= n_sram_raddr_bias;         
        // write enable for SRAM groups A & B
        sram_wen_a0 <= n_sram_wen_a0;
        sram_wen_a2 <= n_sram_wen_a2;
        sram_wen_a1 <= n_sram_wen_a1;
        sram_wen_a3 <= n_sram_wen_a3;
        sram_wen_b0 <= n_sram_wen_b0;
        sram_wen_b1 <= n_sram_wen_b1;
        sram_wen_b2 <= n_sram_wen_b2;
        sram_wen_b3 <= n_sram_wen_b3;
        // word mask for SRAM groups A & B
        sram_wordmask_a <= n_sram_wordmask_a;
        sram_wordmask_b <= n_sram_wordmask_b;
        // write addrress to SRAM groups A & B
        sram_waddr_a <= n_sram_waddr_a;
        sram_waddr_b <= n_sram_waddr_b;
        // write data to SRAM groups A & B
        sram_wdata_a <= n_sram_wdata_a;
        sram_wdata_b <= n_sram_wdata_b;
        //===================================//
        //===================================//
        valid <= n_valid;
        state <= n_state;
        cnt <= n_cnt;
        // CONV1_dw
        for(i=0;i<36;i=i+1) begin
            map0[i] <= n_map0[i];
            map1[i] <= n_map1[i];
            map2[i] <= n_map2[i];
            map3[i] <= n_map3[i];
        end
        for(i=0; i<54; i=i+1) begin
            weight0_dw[i] <= n_weight0_dw[i];
            weight1_dw[i] <= n_weight1_dw[i];
            weight2_dw[i] <= n_weight2_dw[i];
            weight3_dw[i] <= n_weight3_dw[i];
        end
        for(i=0; i<4; i=i+1) begin
            bias_dw[i] <= n_bias_dw[i];
        end
        // CONV1_pw
        for(i=0; i<16; i=i+1) begin
            feature_map0_pw[i] <= n_feature_map0_pw[i];
            feature_map1_pw[i] <= n_feature_map1_pw[i];
            feature_map2_pw[i] <= n_feature_map2_pw[i];
            feature_map3_pw[i] <= n_feature_map3_pw[i];
        end
        for(i=0; i<48; i=i+1) begin
            weight_pw[i] <= n_weight_pw[i];
        end
        for(i=0; i<12; i=i+1) begin
            bias_pw[i] <= n_bias_pw[i];
        end
        for(i=0; i<4; i=i+1) begin
            convolved_temp_b0[i] <= n_convolved_temp_b0[i];
            convolved_temp_b1[i] <= n_convolved_temp_b1[i];
            convolved_temp_b2[i] <= n_convolved_temp_b2[i];
            convolved_temp_b3[i] <= n_convolved_temp_b3[i];
        end
    end
end

endmodule