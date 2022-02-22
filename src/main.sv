
`timescale 1ns/1ns
module tb();
    logic [3:0] KEY;
    logic [9:0] SW;
    logic CLOCK;
    logic [6:0] HEX6, HEX5, HEX3, HEX2, HEX1, HEX0;
    logic [9:0] LEDR;

    assign #10 CLOCK = ~CLOCK;

    /*Defining the wires to interface with the processor*/
    logic [15:0] DataIn, InstrIn; //input ports for data and instructions
    logic DataWaitreq;
    logic Reset, Clock, Enable; //control signals
    logic [15:0] DataOut; //Output Data Port for Writes
    logic [15:0] DataAddr, InstrAddr; //Address ports for data and instructions
    logic WriteData, ReadData; //Instr always assumed read=1

    /*Defining the design for testing*/
    inst_mem InstrMem (InstrAddr[11:0], CLOCK, 16'b0, 1'b0, InstrIn);
    inst_mem DataMem (DataAddr[11:0], CLOCK, DataOut, WriteData, DataIn);
    //some initilizations
    always_comb begin
        DataWaitreq=0;
        Reset=0;
        Clock = CLOCK;
        Enable=1;
    end

    processor proc(DataIn, InstrIn, DataWaitreq, Reset, Clock, Enable, DataOut, DataAddr, InstrAddr, WriteData, ReadData);



endmodule