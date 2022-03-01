
`timescale 1ns/1ns
module tb();

    logic CLOCK;
    assign Clock=CLOCK;

    /*Defining the wires to interface with the processor*/
    logic [15:0] DataIn, InstrIn; //input ports for data and instructions
    logic DataDone;
    logic Reset, Enable; //control signals
    logic [15:0] DataOut; //Output Data Port for Writes
    logic [15:0] DataAddr, InstrAddr; //Address ports for data and instructions
    wire WriteData, ReadData, ResetWire; //Instr always assumed read=1

    assign #10 CLOCK = (~CLOCK & ~Reset);
    assign ResetWire=Reset;

    /*Defining the design for testing*/
    inst_mem InstrMem (InstrAddr[11:0], Clock, 16'b0, 1'b0, InstrIn);
    //some initilizations
    always_comb begin
        Enable=1;
    end

    avalon_bus data_bus(Clock, ReadData, WriteData, ResetWire, DataOut, DataAddr, DataIn, DataDone);

    processor proc(DataIn, InstrIn, DataDone, Reset, Clock, Enable, DataOut, DataAddr, InstrAddr, WriteData, ReadData);

    
    initial begin
        Reset = 1;
        #15
        Reset = 0;
        for (integer i = 0; i < 10000; i++) begin
            @(posedge Clock);
            if (WriteData && (DataAddr == 16'hffff)) begin
                $display("Processor sent kill command");
                $stop();
            end
        end
        $stop();
    end


endmodule