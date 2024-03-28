//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

`timescale 1ns/100ps

module test_enigma_part2;
//ctl
reg clk, srst_n;
reg load;    // load control signal (level sensitive). 0/1: inactive/active
             // effective in ST_IDLE and ST_LOAD states
reg encrypt; // encrypt control signal (level sensitive). 0/1: inactive/active
             // effective in ST_READY state
reg crypt_mode;         // 0: encrypt; 1:decrypt;

//input
reg [6-1:0] code_in;
reg [2-1:0] table_idx;  // table_idx indicates which rotor to be load
            // 2'b00: plug board
            // 2'b01: rotorA
            // 2'b10: rotorB

//output
wire [6-1:0] code_out;
wire code_valid;
//data
reg [6-1:0] data_in [0:27-1];
reg [6-1:0] data_out [0:27-1];
reg [6-1:0] table_in [0:64-1];
//parameter
localparam CYCLE = 10;
reg success = 1;
integer m, n;


enigma_part2 U0(
  .clk(clk),
  .srst_n(srst_n),
  .load(load),
  .encrypt(encrypt),
  .crypt_mode(crypt_mode),
  .table_idx(table_idx),
  .code_in(code_in),
  .code_out(code_out),
  .code_valid(code_valid)
  );

always #(CYCLE/2) clk = ~clk;
//reset
initial begin
  clk = 0;
  srst_n = 1;

  #(CYCLE) srst_n = 0;
  #(CYCLE) srst_n = 1;
end

initial begin
  `ifdef EN
    `ifdef PAT1
      $readmemh("./pat/part2_plaintext1.dat",data_in);
      $readmemh("./pat/part2_ciphertext1.dat",data_out);
    `endif
    `ifdef PAT2
      $readmemh("./pat/part2_plaintext2.dat",data_in);
      $readmemh("./pat/part2_ciphertext2.dat",data_out);
    `endif
  `endif
  `ifdef DE
    `ifdef PAT1
      $readmemh("./pat/part2_ciphertext1.dat",data_in);
      $readmemh("./pat/part2_plaintext1.dat",data_out);
    `endif
    `ifdef PAT2
      $readmemh("./pat/part2_ciphertext2.dat",data_in);
      $readmemh("./pat/part2_plaintext2.dat",data_out);
    `endif
  `endif
end

initial begin
  load = 0;
  code_in = 0;
  encrypt = 0;
  table_idx = 2'd3;
  `ifdef EN
    crypt_mode = 0;
  `endif
  `ifdef DE
    crypt_mode = 1;
  `endif

  wait(srst_n==0);
  wait(srst_n==1);
  #(CYCLE);

  load = 1;
  //Load Rotor A
  $readmemh("./rotor/rotorA.dat",table_in);
  table_idx = 2'b01;
  for(m=0; m<64; m=m+1) begin
    @(negedge clk);
    code_in = table_in[m][6-1:0];
  end
  //Load Rotor B
  $readmemh("./rotor/rotorB.dat",table_in);
  for(m=0; m<64; m=m+1) begin
    @(negedge clk);
    table_idx = 2'b10;
    code_in = table_in[m][6-1:0];
  end

  @(negedge clk);
  load = 0;
  table_idx = 2'd3;
  @(posedge clk)
  table_idx = 2'd3;

  for(n=0; n<27; n=n+1) begin
    @(negedge clk)
    encrypt = 1;
    code_in = data_in[n][6-1:0];
    @(posedge clk) #1;
    if(code_out !== data_out[n][6-1:0]) begin
      success = 0;
      $display("************* Pattern No.%d is wrong ************",n);
      $display("code out is %h, but the result should be %h",code_out[6-1:0],data_out[n][6-1:0]);
      $display("");
    end
  end

  if(success) begin
    $display("");
    $display("");
    $display("*******************************************************************");
    $display("***************** Correct and Congratulations !!! *****************");
    $display("*******************************************************************");
    $display("");
    $display("");
    $finish;
  end
  $finish;
end

initial begin
  `ifdef EN
    `ifdef PAT1
      $fsdbDumpfile("part2_en_pat1.fsdb");
      $fsdbDumpvars;
    `endif
    `ifdef PAT2
      $fsdbDumpfile("part2_en_pat2.fsdb");
      $fsdbDumpvars;
    `endif
  `endif
  `ifdef DE
    `ifdef PAT1
      $fsdbDumpfile("part2_de_pat1.fsdb");
      $fsdbDumpvars;
    `endif
    `ifdef PAT2
      $fsdbDumpfile("part2_de_pat2.fsdb");
      $fsdbDumpvars;
    `endif
  `endif
end

endmodule
