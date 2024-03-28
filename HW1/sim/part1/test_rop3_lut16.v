`define CYCLE 10
`define TEST_DATA_NUM 61440
`define N 8 
`define END_CYCLE 10000000

module test_rop3_lut16;

// dump waveform (optional)
/* -If you already know how to use verdi (which would be taught in later lab), 
    you can uncomment this part to generate fsdb file and load into verdi to check waveform.
   -If you don't know how to use verdi yet, don't worry and just ignore this part now.
    You can debug by using the "$display" command in the testbench to print the informantion during simulation. */
// initial begin
//     $fsdbDumpfile("rop3_lut16.fsdb");
//     $fsdbDumpvars("+mda");
// end

// pattern files
reg [50*8-1:0] PATH_INPUT;
reg [50*8-1:0] PATH_GOLDEN;
initial begin
    $display("Start to simulate N=%0d ...", `N);
    if(`N == 4) begin
        PATH_INPUT = "./data/rop3_lut16_N4_input.dat";
        PATH_GOLDEN = "./data/rop3_lut16_N4_golden.dat";
    end
    else if(`N == 8) begin
        PATH_INPUT = "./data/rop3_lut16_N8_input.dat";
        PATH_GOLDEN = "./data/rop3_lut16_N8_golden.dat";
    end
    $display("PATH_INPUT is \"%0s\"", PATH_INPUT);
    $display("PATH_GOLDEN is \"%0s\"", PATH_GOLDEN);
end

// create clk
reg clk;
initial begin
    clk = 0;
    while(1) #(`CYCLE/2) clk = ~clk;
end

// RTL instantiation
reg srst_n;
reg [`N-1:0] Bitmap;
reg [7:0] Mode;
wire [`N-1:0] Result_RTL;
wire valid;

rop3_lut16 #(.N(`N)) ROP3_U0
(
  .clk(clk),
  .srst_n(srst_n),
  .Bitmap(Bitmap),
  .Mode(Mode),
  .Result(Result_RTL),
  .valid(valid)
);

// input feeding
integer read_valid;
integer fp_in;
integer input_i;
reg [(8+3*`N)-1:0] buff_in;
reg [`N-1:0] P_in, S_in, D_in;
reg [7:0] Mode_in;
reg [`N-1:0] P_last, S_last, D_last;
reg [7:0] Mode_last;
reg [1:0] cnt;

initial begin
    // input feeding init
    fp_in = $fopen(PATH_INPUT, "r");
    Mode = {8{1'bz}};
    Bitmap = {`N{1'bz}};
    cnt = 1;
    input_i = 0;

    // reset
    srst_n = 1;
    @(posedge clk); #1; srst_n = 0;
    @(posedge clk);
    @(posedge clk); #1; srst_n = 1;

    // input feeding start
    while(input_i < `TEST_DATA_NUM) begin
        // read new pattern
        read_valid = $fscanf(fp_in, "%h", buff_in);
        // $display("read_valid = %d", read_valid);
        {Mode_last, P_last, S_last, D_last} = {Mode_in, P_in, S_in, D_in};
        {Mode_in, P_in, S_in, D_in} = buff_in;

        // feed pattern
        repeat(3) begin
            @(posedge clk); #1;
            Mode = Mode_in;
            feed_bitmap(P_in, S_in, D_in, cnt, Bitmap);
        end

        input_i = input_i + 1;
    end

    // input feeding stop
    {Mode_last, P_last, S_last, D_last} = {Mode_in, P_in, S_in, D_in};
    $fclose(fp_in);
    @(posedge clk); #1;
    Mode = {8{1'bz}};
    Bitmap = {`N{1'bz}};
end

// output comparision
integer m;
integer fout;
integer fp_gold;
integer output_i;
integer total_error;
reg [`N-1:0] Result_Golden;

initial begin
    // open output file
    fout = $fopen("sim_out_part1.csv");
    // write title
    $fwrite(fout, "Mode,P,S,D,Result_RTL,Result_Golden\n");

    // output comparison init
    fp_gold = $fopen(PATH_GOLDEN, "r");
    output_i = 0;
    total_error = 0;

    // output comparison start
    while(output_i < `TEST_DATA_NUM) begin
        @(negedge clk);
        if(valid == 1) begin
            // read golden
            read_valid = $fscanf(fp_gold, "%h", Result_Golden);
            // $display("read_valid = %d", read_valid);

            // compare
            if (Result_Golden !== Result_RTL) begin
                $display("!!!!! Comparison Fail @ pattern %0d !!!!!", output_i);
                $display("[pattern %0d]        Mode=%h, {P,S,D}={%h,%h,%h}, RTL=%h, Answer=%h",
                        output_i, Mode_last, P_last, S_last, D_last, Result_RTL, Result_Golden);
                total_error = total_error + 1;
            end 
            else begin
                // $display(">>>>> Comparison Pass @ pattern %0d <<<<<", output_i);
                // $display("[pattern %0d]        Mode=%h, {P,S,D}={%h,%h,%h}, RTL=%h, Answer=%h",
                //         output_i, Mode_last, P_last, S_last, D_last, Result_RTL, Result_Golden);
            end

            // write to output file
            $fwrite(fout, "%h,%h,%h,%h,%h,%h\n", Mode_last, P_last, S_last, D_last, Result_RTL, Result_Golden);

            output_i = output_i + 1;
        end
    end
    // summary
    $fclose(fp_gold);
    $fclose(fout);
    if (total_error > 0) begin
        $display("\nxxxxxxxxxxx Comparison Fail xxxxxxxxxxx");
        $display("            Total %0d errors\n  Please check your error messages...", total_error);
        $display("xxxxxxxxxxx Comparison Fail xxxxxxxxxxx\n");
    end 
    else begin
        $display("\n============= Congratulations =============");
        $display("    You can move on to the next part !");
        $display("============= Congratulations =============\n");
    end
    $finish;
end

// terminate simulation if it takes too long
initial begin
	#(`CYCLE * `END_CYCLE);
	$display("\n===================================================");
	$display("      Error!!! Simulation time is too long...      ");
	$display("   There might be something wrong in your code.    ");
 	$display("===================================================\n");
 	$finish;
end

task feed_bitmap;
    input [`N-1:0] P_in;
    input [`N-1:0] S_in;
    input [`N-1:0] D_in;
    inout [1:0] cnt;
    output [`N-1:0] Bitmap;
    begin
        if(cnt == 2'd1) begin
            Bitmap = P_in;
            cnt = cnt + 1;
        end
        else if(cnt == 2'd2) begin
            Bitmap = S_in;
            cnt = cnt + 1;
        end
        else if(cnt == 2'd3) begin
            Bitmap = D_in;
            cnt = 1;
        end
    end
endtask

endmodule