
`timescale 1ns/1ns
module tb();

    logic CLOCK;

    /*Defining the wires to interface with the processor*/
    logic [15:0] DataIn, InstrIn; //input ports for data and instructions
    logic Waitreq;
    logic Reset, Clock, Enable; //control signals
    logic [15:0] DataOut; //Output Data Port for Writes
    logic [15:0] DataAddr, InstrAddr; //Address ports for data and instructions
    logic WriteData, ReadData; //Instr always assumed read=1

    assign #10 CLOCK = (~CLOCK & ~Reset);

    /*Defining the design for testing*/
    inst_mem InstrMem (InstrAddr[11:0], CLOCK, 16'b0, 1'b0, InstrIn);
    //some initilizations
    always_comb begin
        Clock = CLOCK;
        Enable=1;
    end

    avalon_bus(CLOCK, ReadData, WriteData, DataOut, DataAddr, DataIn, Waitreq);

    processor proc(DataIn, InstrIn, ~Waitreq, Reset, Clock, Enable, DataOut, DataAddr, InstrAddr, WriteData, ReadData);

    
    initial begin
        Reset = 1;
        #15
        Reset = 0;
        #100000
        $stop();
    end


endmodule