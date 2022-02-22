
`timescale 1ns/1ns
module tb();

    logic CLOCK;

    /*Defining the wires to interface with the processor*/
    logic [15:0] DataIn, InstrIn; //input ports for data and instructions
    logic DataDone;
    logic Reset, Clock, Enable; //control signals
    logic [15:0] DataOut; //Output Data Port for Writes
    logic [15:0] DataAddr, InstrAddr; //Address ports for data and instructions
    logic WriteData, ReadData; //Instr always assumed read=1

    assign #10 CLOCK = (~CLOCK & ~Reset);

    /*Defining the design for testing*/
    inst_mem InstrMem (InstrAddr[11:0], CLOCK, 16'b0, 1'b0, InstrIn);
    inst_mem DataMem (DataAddr[11:0], CLOCK, DataOut, WriteData, DataIn);
    //some initilizations
    always_comb begin
        Clock = CLOCK;
        Enable=1;
    end

    processor proc(DataIn, InstrIn, DataDone, Reset, Clock, Enable, DataOut, DataAddr, InstrAddr, WriteData, ReadData);

    logic [3:0] waiting_cycles;
    always_ff@(posedge CLOCK, posedge Reset) begin
        if (Reset)
            waiting_cycles <= 0;
        else if (waiting_cycles > 0)
            waiting_cycles <= waiting_cycles-1; //decrement waiting cycles
        else if (waiting_cycles == 0 && (WriteData || ReadData))
            waiting_cycles <= 5; //reset the waiting cycles, started a new operation
    end
    assign DataDone = waiting_cycles==0;
    
    initial begin
        Reset = 1;
        #15
        Reset = 0;
        #1000
        $stop();
    end


endmodule