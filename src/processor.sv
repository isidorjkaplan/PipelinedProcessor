module processor (
    input [WORD_SIZE-1:0] DataIn, InstIn //input ports for data and instructions
    input Reset, Clock, Enable, //control signals
    output [WORD_SIZE-1:0] DataOut, //Output Data Port for Writes
    output [WORD_SIZE-1:0] DataAddr, InstAddr //Address ports for data and instructions
    output WriteData, ReadData //Instr always assumed read=1
);
    parameter MUM_REGS = 8;
    parameter WORD_SIZE = 16;

    /*Define the registers*/
    logic [WORD_SIZE-1:0] registers[NUM_REGS];
    
endmodule