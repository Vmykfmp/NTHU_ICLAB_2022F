//==================================================================================================
//  Note:          Use only for teaching materials of IC Design Lab, NTHU.
//  Copyright: (c) 2022 Vision Circuits and Systems Lab, NTHU, Taiwan. ALL Rights Reserved.
//==================================================================================================
 
module show_enigma_code;

parameter FILENAME_LENGTH = 26;

`ifdef PAT1
    localparam pat_len = 27;
`elsif PAT2
    localparam pat_len = 112;
`elsif PAT3
    localparam pat_len = 50868;
`endif 

`include "display_enigma_code.v"

initial begin

    `ifdef PAT1
        display_enigma_code("./pat/part3_plaintext1.dat");
    `elsif PAT2
        display_enigma_code("./pat/part3_plaintext2.dat");
    `endif 

    #10 $finish;

end

endmodule
