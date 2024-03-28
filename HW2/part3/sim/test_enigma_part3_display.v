//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================

`timescale 1ns/100ps

module test_enigma_part3_display;

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
//parameter
`ifdef PAT2
  localparam  pat_len = 112;
`elsif PAT3
  localparam  pat_len = 50868;
`endif
localparam CYCLE = 10;
integer m, n, f;
//data
reg [6-1:0] data_in [0:pat_len-1];
reg [6-1:0] table_in [0:64-1];
reg [7:0] ascii_code;

enigma_part3 U0(
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
  `ifdef PAT2
    $readmemh("./pat/part3_ciphertext2.dat",data_in);
  `elsif PAT3
    $readmemh("./pat/part3_ciphertext3.dat",data_in);
  `endif
end

initial begin
  load = 0;
  code_in = 0;
  encrypt = 0;
  crypt_mode = 1;
  table_idx = 2'd3;

  `ifdef PAT2
    f = $fopen("plaintext2_ascii.dat","w");
  `elsif PAT3
    f = $fopen("plaintext3_ascii.dat","w");
  `endif

  wait(srst_n==0);
  wait(srst_n==1);
  #(CYCLE);

  load = 1;
  //Load Plug Board
  $readmemh("./rotor/plug_board_group.dat",table_in);
  table_idx = 2'b00;
  for(m=0; m<32; m=m+1) begin
    @(negedge clk);
    code_in = table_in[m][6-1:0];
  end
  //Load Rotor A
  $readmemh("./rotor/rotorA.dat",table_in);
  for(m=0; m<64; m=m+1) begin
    @(negedge clk);
    table_idx = 2'b01;
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

  $write("\n\n");
  for(n=0; n<pat_len; n=n+1) begin
    @(negedge clk)
    encrypt = 1;
    table_idx = 2'd3;
    code_in = data_in[n][6-1:0];
    @(posedge clk) #1;
    EnigmaCodetoASCII(code_out,ascii_code);
    $write("%s",ascii_code);
    $fwriteh(f,"%s" ,ascii_code);
  end
  $write("\n\n");
  $fclose(f);
  $finish;
end

task EnigmaCodetoASCII;
  input [6-1:0] eingmacode;
  output [8-1:0] ascii_out;
  reg [8-1:0] ascii_out;

  begin
    case(eingmacode)
      6'h00: ascii_out = 8'h61; //'a'
      6'h01: ascii_out = 8'h62; //'b'
      6'h02: ascii_out = 8'h63; //'c'
      6'h03: ascii_out = 8'h64; //'d'
      6'h04: ascii_out = 8'h65; //'e'
      6'h05: ascii_out = 8'h66; //'f'
      6'h06: ascii_out = 8'h67; //'g'
      6'h07: ascii_out = 8'h68; //'h'
      6'h08: ascii_out = 8'h69; //'i'
      6'h09: ascii_out = 8'h6a; //'j'
      6'h0a: ascii_out = 8'h6b; //'k'
      6'h0b: ascii_out = 8'h6c; //'l'
      6'h0c: ascii_out = 8'h6d; //'m'
      6'h0d: ascii_out = 8'h6e; //'n'
      6'h0e: ascii_out = 8'h6f; //'o'
      6'h0f: ascii_out = 8'h70; //'p'
      6'h10: ascii_out = 8'h71; //'q'
      6'h11: ascii_out = 8'h72; //'r'
      6'h12: ascii_out = 8'h73; //'s'
      6'h13: ascii_out = 8'h74; //'t'
      6'h14: ascii_out = 8'h75; //'u'
      6'h15: ascii_out = 8'h76; //'v'
      6'h16: ascii_out = 8'h77; //'w'
      6'h17: ascii_out = 8'h78; //'x'
      6'h18: ascii_out = 8'h79; //'y'
      6'h19: ascii_out = 8'h7a; //'z'
      6'h1a: ascii_out = 8'h20; //' '
      6'h1b: ascii_out = 8'h3f; //'?'
      6'h1c: ascii_out = 8'h2c; //','
      6'h1d: ascii_out = 8'h2d; //'-'
      6'h1e: ascii_out = 8'h2e; //'.'
      6'h1f: ascii_out = 8'h0a; //'\n' (change line)
      6'h20: ascii_out = 8'h41; //'A'
      6'h21: ascii_out = 8'h42; //'B'
      6'h22: ascii_out = 8'h43; //'C'
      6'h23: ascii_out = 8'h44; //'D'
      6'h24: ascii_out = 8'h45; //'E'
      6'h25: ascii_out = 8'h46; //'F'
      6'h26: ascii_out = 8'h47; //'G'
      6'h27: ascii_out = 8'h48; //'H'
      6'h28: ascii_out = 8'h49; //'I'
      6'h29: ascii_out = 8'h4a; //'J'
      6'h2a: ascii_out = 8'h4b; //'K'
      6'h2b: ascii_out = 8'h4c; //'L'
      6'h2c: ascii_out = 8'h4d; //'M'
      6'h2d: ascii_out = 8'h4e; //'N'
      6'h2e: ascii_out = 8'h4f; //'O'
      6'h2f: ascii_out = 8'h50; //'P'
      6'h30: ascii_out = 8'h51; //'Q'
      6'h31: ascii_out = 8'h52; //'R'
      6'h32: ascii_out = 8'h53; //'S'
      6'h33: ascii_out = 8'h54; //'T'
      6'h34: ascii_out = 8'h55; //'U'
      6'h35: ascii_out = 8'h56; //'V'
      6'h36: ascii_out = 8'h57; //'W'
      6'h37: ascii_out = 8'h58; //'X'
      6'h38: ascii_out = 8'h59; //'Y'
      6'h39: ascii_out = 8'h5a; //'Z'
      6'h3a: ascii_out = 8'h3a; //':'
      6'h3b: ascii_out = 8'h23; //'#'
      6'h3c: ascii_out = 8'h3b; //';'
      6'h3d: ascii_out = 8'h5f; //'_'
      6'h3e: ascii_out = 8'h2b; //'+'
      6'h3f: ascii_out = 8'h26; //'&'
    endcase
  end
endtask

endmodule
