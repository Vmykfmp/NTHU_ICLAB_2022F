module test_rop3_lut256;

parameter CYCLE = 10;
//parameter N = 1;
`define N 1
parameter DATA_WIDTH = 2**`N;
parameter MODE_WIDTH = 256;

integer i, j, k, l, m;
integer data_num;
integer fout;

reg clk, srst_n;
reg [`N-1:0] Bitmap;
reg [7:0] Mode;

wire [`N-1:0] Result_lut256, Result_smart;
wire valid_lut16, valid_smart;
reg success;

  rop3_lut256 #(.N(`N)) ROP3_LUT256_U0(
    .clk(clk),
    .srst_n(srst_n),
    .Bitmap(Bitmap),
    .Mode(Mode),
    .Result(Result_lut256),
    .valid(valid_lut256)
  );

  rop3_smart #(.N(`N)) ROP3_SMART_U0(
    .clk(clk),
    .srst_n(srst_n),
    .Bitmap(Bitmap),
    .Mode(Mode),
    .Result(Result_smart),
    .valid(valid_smart)
    );

always #(CYCLE/2) clk = ~clk;
//reset
initial begin
  clk = 1;
  srst_n = 1;

  #(CYCLE) srst_n = 0;
  #(CYCLE) srst_n = 1;
end
//test
initial begin
  Mode = 8'b0;
  Bitmap = 8'b0;
  success = 1'b0;
  data_num = 0;

  wait(srst_n==0);
  wait(srst_n==1);

  fout = $fopen("sim_out_part3.csv");
  $fwrite(fout, "Mode,P,S,D,Result_lut256,Result_smart\n");
  for(i=0; i<MODE_WIDTH; i=i+1) begin
    Mode = i[7:0];
    for(j=0; j<DATA_WIDTH; j=j+1) begin
      for(k=0; k<DATA_WIDTH; k=k+1) begin
        for(l=0; l<DATA_WIDTH; l=l+1) begin
          //Bitmap_load
          for(m=0; m<3; m=m+1) begin
            data_num = data_num + 1;
            @(negedge clk); #1;
            case(m[1:0])
              2'b00 : Bitmap = j[`N-1:0];//Pin;
              2'b01 : Bitmap = k[`N-1:0];//Sin;
              2'b10 : Bitmap = l[`N-1:0];//Din;
              default : Bitmap = 0;
            endcase
          end
          //Result_compare
          @(posedge clk);
          if(Result_lut256 !== Result_smart) begin
            success = 1'b1;
            $display("************************************* Result incorrect! ************************************************");
            $display("P=%b, S=%b, D=%b",j[`N-1:0] ,k[`N-1:0] ,l[`N-1:0]);//,Pin ,Sin, Din);
            $display("M=%h, Rlut=%b, Rsmart=%b",Mode, Result_lut256, Result_smart);
          end
          //Output_csv
          $fwrite(fout, "%h,%b,%b,%b,%b,%b\n", Mode, j[`N-1:0], k[`N-1:0], l[`N-1:0], Result_lut256[`N-1:0], Result_smart[`N-1:0]);
        end
      end
    end
  end
  if(!success) $display("************************************* Result correct! %d ************************************",data_num);
  $fclose(fout);
  $finish;
end

endmodule
