//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

module qrcode_decoder(
    input clk,
    input srst_n,             
    input start,                         
    input sram_rdata,       

    output reg [11:0] sram_raddr,
    output reg [5:0] loc_y,
    output reg [5:0] loc_x,
    output reg [7:0] decode_text,
    output reg valid,
    output reg finish         
);

reg [11:0] n_sram_raddr;
reg [7:0] n_decode_text;
reg [5:0] n_loc_y;
reg [5:0] n_loc_x;
reg n_finish;
reg n_valid;

localparam IDLE = 3'b000, LOC = 3'b001, ROTAT = 3'b010, MASK = 3'b011, READ = 3'b100, WRITE = 3'b101;
reg [2:0]state, n_state;
reg [8:0]cnt, n_cnt;

reg [2:0]rot, n_rot;
reg rot_done, n_rot_done;
reg rot_pause, n_rot_pause;

reg [2:0] mask_ID, n_mask_ID;
reg [152-1:0] codeword;
reg [152-1:0] n_codeword;
reg [8-1:0] length;
reg [5:0] i_index, n_i_index; 
reg [5:0] j_index, n_j_index;
integer i, j;

//fsm
always @* begin
    case (state) //synopys parallel_case
        IDLE: begin
            n_state = IDLE;
            n_sram_raddr = 0;
            n_rot = rot;
            n_loc_x = 0;
            n_loc_y = 0;
            n_i_index = 0;
            n_j_index = 0;
            n_rot_done = 0;
            n_rot_pause = 0; 
            if(start) begin
                n_state = LOC;
                //$finish;
            end
        end 
        LOC : begin
            n_state = LOC;
            n_sram_raddr = sram_raddr + 1;
            n_rot = rot;
            n_loc_x = loc_x;
            n_loc_y = loc_y;
            n_i_index = 0;
            n_j_index = 0;
            n_rot_done = 0;
            n_rot_pause = 0;     
            if(sram_rdata) begin
                n_state = ROTAT;
                n_loc_x = sram_raddr%64;
                n_loc_y = sram_raddr/64;
                n_sram_raddr = sram_raddr;
                //temp_loc_x = n_loc_x;
            end
            //n_sram_raddr = 514;
        end
        ROTAT: begin
            n_state = ROTAT;
            n_sram_raddr = sram_raddr + 1;
            n_rot = rot;
            n_loc_x = loc_x;
            n_loc_y = loc_y;
            n_i_index = i_index;
            n_j_index = j_index;
            n_rot_done = rot_done;
            n_rot_pause = rot_pause;
            if(rot_done) begin
                n_state = MASK;
                n_rot_done = 0;
                n_i_index = 2;
                n_j_index = 8;
                case (rot)
                    3'b111: begin //0
                        n_loc_x = loc_x;
                        n_loc_y = loc_y;
                        n_sram_raddr = loc_x + 64*loc_y + 514;
                    end
                    3'b101: begin //90
                        n_loc_x = loc_x;
                        n_loc_y = loc_y + 20;
                        n_sram_raddr = loc_x + 64*loc_y + 1160;
                    end
                    3'b110: begin //180
                        n_loc_x = loc_x + 20;
                        n_loc_y = loc_y + 20;
                        n_sram_raddr = loc_x + 64*loc_y + 786; 
                    end
                    3'b011: begin //270
                        n_loc_x = loc_x + 20;
                        n_loc_y = loc_y;
                        n_sram_raddr = loc_x + 64*loc_y + 140; 
                    end
                    3'b000: begin //180_0
                        n_loc_x = loc_x + 20;//+ 19;
                        n_loc_y = loc_y + 20;
                        n_sram_raddr = loc_x + 64*loc_y + 786;//+ 785;
                    end
                    default: begin
                        n_loc_x = loc_x;
                        n_loc_y = loc_y;
                        n_sram_raddr = loc_x + 64*loc_y + 514;
                    end
                endcase
            end
            else if(sram_raddr/64 == loc_y) begin
                n_rot_done = 0;
                n_rot_pause = 0;
                //$display("loc_x = %3d",(sram_raddr%64));
                if(sram_raddr%64 < loc_x+7) begin
                    if(~sram_rdata) begin
                        n_rot[0] = 0;
                        n_sram_raddr = loc_x+(64*loc_y)+14;
                        n_rot_pause = 1;
                    end
                    else if(sram_raddr%64 == loc_x+6) begin
                        n_rot[0] = 1;
                        n_sram_raddr = loc_x+(64*loc_y)+14;
                    end
                end
                else if(rot_pause & (sram_raddr == loc_x+(64*loc_y)+14)) begin
                    n_rot = rot;
                    n_rot_pause = 0;
                    n_sram_raddr = sram_raddr;
                end
                else begin
                    if(~sram_rdata) begin
                        n_rot[1] = 0;
                        n_sram_raddr = loc_x+64*(loc_y+14);
                        if(~n_rot[0]) begin
                            n_loc_x = ((sram_raddr- 21)%64);
                            //$display("new loc_x = %4d",n_loc_x);
                        end 
                    end
                    else if(sram_raddr%64 == loc_x+20) begin
                        n_rot[1] = 1;
                        n_sram_raddr = loc_x+64*(loc_y+14);
                    end      
                end
            end
            else begin
                n_rot_done = 0;
                n_sram_raddr = sram_raddr + 64;
                if(~sram_rdata) begin
                    n_rot[2] = 0;
                    n_rot_done = 1;
                end
                else if(sram_raddr/64 == loc_y+20)begin
                    n_rot[2] = 1;
                    n_rot_done = 1;
                end
            end
        end
        MASK: begin
            n_state = MASK;
            n_rot = rot;
            n_loc_x = loc_x;
            n_loc_y = loc_y;

            n_i_index = i_index + 1;
            n_j_index = 8;
            n_rot_done = rot_done;
            n_rot_pause = rot_pause;
            n_sram_raddr = (loc_x + n_i_index) + 64*(loc_y + n_j_index);
            case (rot)
                3'b111: begin //0
                    n_sram_raddr = (loc_x + n_i_index) + 64*(loc_y + n_j_index);
                end
                3'b101: begin //90
                    n_sram_raddr = (loc_x + n_j_index) + 64*(loc_y - n_i_index);
                end
                3'b110: begin //180
                    n_sram_raddr = (loc_x - n_i_index) + 64*(loc_y - n_j_index);
                end
                3'b011: begin //270
                    n_sram_raddr = (loc_x - n_j_index) + 64*(loc_y + n_i_index);
                end
                3'b000: begin //180_0
                    n_sram_raddr = (loc_x - n_i_index) + 64*(loc_y - n_j_index);
                    //$display("%4d i(%2d) j(%2d)",sram_raddr,i_index,j_index);
                end
                default: begin
                    n_sram_raddr = (loc_x + n_i_index) + 64*(loc_y + n_j_index);
                end
            endcase
            //$display("mask addr : %4d (%2d)",sram_raddr,i_index);
            if(i_index == 4) begin
                n_state = READ;
                
                //n_sram_raddr = sram_raddr;
                n_i_index = 20;
                n_j_index = 20;
                //$display("MASK : %3b",mask_ID);
                //case (rot)
            end

        end
        READ: begin
            n_state = READ;
            n_rot = rot;
            n_loc_x = loc_x;
            n_loc_y = loc_y;
            n_rot_done = rot_done;
            n_rot_pause = rot_pause;

            n_i_index = i_index - 1;
            n_j_index = j_index;
            if(j_index > 8) begin
                if(i_index == 11) begin
                    n_j_index = j_index - 1;
                    if(j_index == 9)
                        n_i_index = 12;
                    else
                        n_i_index = 20;
                end
            end
            else begin
                if(i_index == 9) begin
                    n_i_index = 12;
                    if(j_index == 7)
                        n_j_index = j_index - 2;
                    else if(j_index == 0) begin
                        n_i_index = 0;
                        n_j_index = 0;
                        n_state = WRITE;
                    end
                    else
                        n_j_index = j_index - 1;
                end
            end

            n_sram_raddr = (loc_x + n_i_index) + 64*(loc_y + n_j_index);
            case (rot)
                3'b111: begin //0
                    n_sram_raddr = (loc_x + n_i_index) + 64*(loc_y + n_j_index);
                end
                3'b101: begin //90
                    n_sram_raddr = (loc_x + n_j_index) + 64*(loc_y - n_i_index);
                end
                3'b110: begin //180
                    n_sram_raddr = (loc_x - n_i_index) + 64*(loc_y - n_j_index);
                end
                3'b011: begin //270
                    n_sram_raddr = (loc_x - n_j_index) + 64*(loc_y + n_i_index);
                end
                3'b000: begin //180_0
                    n_sram_raddr = (loc_x - n_i_index) + 64*(loc_y - n_j_index);
                    //$display("%4d i(%2d) j(%2d)",sram_raddr,i_index,j_index);
                end
                default: begin
                    n_sram_raddr = (loc_x + n_i_index) + 64*(loc_y + n_j_index);
                end
            endcase
            //$display("%4d",sram_raddr);
        end
        WRITE: begin
            n_state = WRITE;
            n_sram_raddr = sram_raddr;
            n_rot = rot;
            n_loc_x = loc_x;
            n_loc_y = loc_y;
            n_i_index = i_index;
            n_j_index = j_index;
            n_rot_done = rot_done;
            n_rot_pause = rot_pause;
            if(n_finish) n_state = IDLE;
        end
        default: begin
            n_state = IDLE;
            n_sram_raddr = sram_raddr;
            n_rot = rot;
            n_loc_x = loc_x;
            n_loc_y = loc_y;
            n_i_index = i_index;
            n_j_index = j_index;
            n_rot_done = rot_done;
            n_rot_pause = rot_pause;
        end 
    endcase
end
//mask_pattern
always @* begin
    n_mask_ID = mask_ID;
    if(state == MASK) begin
    case (i_index) //synopys parallel_case
        2: n_mask_ID[2] = sram_rdata^1'b1;
        3: n_mask_ID[1] = sram_rdata^1'b0;
        4: n_mask_ID[0] = sram_rdata^1'b1;
        default: n_mask_ID = 3'b0;
    endcase
    end
end
//decode
always @* begin
    for(i=0; i<152; i=i+1)
        n_codeword[i] = codeword[i];
    if(state == READ) begin
        //$display("%4d (i:%3d, j:%3d)",sram_raddr,i_index,j_index);
        if(j_index > 8) begin
            if((i_index-1)%4 > 1) begin
                if((i_index-1)/4 == 4) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0);
                    3'b101: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[23-2*(j_index-9)-(i_index-19)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
                else if((i_index-1)/4 == 3) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[71-2*(j_index-9)-(i_index-15)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
                else if((i_index-1)/4 == 2) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[119-2*(j_index-9)-(i_index-11)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
            end
            else begin
                if((i_index-1)/4 == 4) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[25+2*(j_index-9)-(i_index-17)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
                else if((i_index-1)/4 == 3) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[73+2*(j_index-9)-(i_index-13)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
            end 
        end
        else begin
            if((i_index-1)%4 > 1) begin
                if((j_index) > 6) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[123-2*(j_index-7)-(i_index-11)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase 
                end
                else begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[135-2*(j_index)-(i_index-11)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase 
                end
            end
            else begin
                if((j_index) > 6) begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[149+2*(j_index-7)-(i_index-9)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
                else begin
                    case (mask_ID)//synopys parallel_case
                    3'b000: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^(((j_index)+(i_index))%2 == 0)?1:0;
                    3'b001: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^((j_index)%2 == 0)?1:0;
                    3'b010: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^((i_index)%3 == 0)?1:0;
                    3'b011: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^(((j_index)+(i_index))%3 == 0)?1:0;
                    3'b100: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^((((j_index)/2)+((i_index)/3))%2 == 0)?1:0;
                    3'b101: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3) == 0)?1:0;
                    3'b110: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^(((((j_index)*(i_index))%2)+(((j_index)*(i_index))%3))%2 == 0)?1:0;
                    3'b111: n_codeword[137+2*(j_index)-(i_index-9)] = sram_rdata^(((((j_index)*(i_index))%3)+(((j_index)+(i_index))%2))%2 == 0)?1:0;
                    endcase
                end
            end
        end
    end
end
//length
always @* begin
    for(i=0; i<8; i=i+1)
        length[i] = codeword[11-i];
end
//output
always @* begin
    n_cnt = cnt;
    n_valid = 0;
    n_finish = 0;
    n_decode_text = decode_text;
    if(state == WRITE) begin
        //$finish;
        //for(i=0; i<152; i=i+1) begin
            //$write("%b",codeword[i]);
            //if(i%8 == 3) $display("");
        //end
        //$finish;
        //$display("%d",cnt);
        n_cnt = cnt + 1;
        n_valid = 1;
        n_finish = 0;
        n_decode_text[0] = codeword[19+cnt*8];
        n_decode_text[1] = codeword[18+cnt*8];
        n_decode_text[2] = codeword[17+cnt*8];
        n_decode_text[3] = codeword[16+cnt*8];
        n_decode_text[4] = codeword[15+cnt*8];
        n_decode_text[5] = codeword[14+cnt*8];
        n_decode_text[6] = codeword[13+cnt*8];
        n_decode_text[7] = codeword[12+cnt*8];
        
        //$display("text : %b ", n_decode_text);

        //if(cnt == 2) $finish;
        if(cnt == length-1) begin
            n_finish = 1;
        end
    end
end
//DFF
always @(posedge clk) begin
    if(!srst_n) begin
        sram_raddr <= 0;
        decode_text <= 0;
        mask_ID <= 0;
        loc_y <= 0;
        loc_x <= 0;
        finish <= 0;
        valid <= 0;
        state <= 0;
        cnt <= 0;
        
        rot <= 0;
        rot_done <= 0;
        rot_pause <= 0;
        for(i=0; i<152; i=i+1)
            codeword[i] <= 0;
        i_index <= 0;
        j_index <= 0;
    end
    else begin
        sram_raddr <= n_sram_raddr;
        decode_text <= n_decode_text;
        mask_ID <= n_mask_ID;
        loc_y <= n_loc_y;
        loc_x <= n_loc_x;
        finish <= n_finish;
        valid <= n_valid;
        state <= n_state;
        cnt <= n_cnt;

        rot <= n_rot;
        rot_done <= n_rot_done;
        rot_pause <= n_rot_pause;
        for(i=0; i<152; i=i+1)
            codeword[i] <= n_codeword[i];
        i_index <= n_i_index;
        j_index <= n_j_index;
    end
end

endmodule