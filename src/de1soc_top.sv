

module de1soc_top (
    input CLOCK_50,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5,
    input [3:0] KEY,
    output [9:0] LEDR,
    input [9:0] SW,
	 input IRDA_RXD, //IR reciever wire
	 output IRDA_TXD, //IR emitter wire
	 inout PS2_CLK,
	 inout PS2_DAT
	 );
    
    /*Defining the wires to interface with the processor*/
    logic [15:0] DataIn, InstrIn; //input ports for data and instructions
    logic DataDone;
    wire Clock, Reset;
    logic Enable; //control signals
    logic [15:0] DataOut; //Output Data Port for Writes
    logic [15:0] DataAddr, InstrAddr; //Address ports for data and instructions
    wire WriteData, ReadData;

    assign Clock=CLOCK_50;
    assign Enable=1;
    assign Reset = ~KEY[3];//use KEY3 as a reset

    /*This defines the instruction memory. It is single-cycle and does not exist on the normal bus*/
    inst_mem InstrMem (InstrAddr[11:0], Clock, 16'b0, 1'b0, InstrIn);
    /*This is the bus that handles all I/O and data memory*/
    logic [6:0] HEX[6];
    assign HEX0 = ~HEX[0];
    assign HEX1 = ~HEX[1];
    assign HEX2 = ~HEX[2];
    assign HEX3 = ~HEX[3];
    assign HEX4 = ~HEX[4];
    assign HEX5 = ~HEX[5];
    
    avalon_bus data_bus(Clock, ReadData, WriteData, Reset, DataOut, DataAddr, DataIn, DataDone, HEX, SW, LEDR, ~KEY, IDRA_RXD, IRDA_TXD, PS2_CLK, PS2_DAT);
    /*The actual processor itself*/
    processor proc(DataIn, InstrIn, DataDone, Reset, Clock, Enable, DataOut, DataAddr, InstrAddr, WriteData, ReadData);
endmodule
