module avalon_ps2
(
	input clk, //Common clock shared by the entire system.
	input reset, //Common reset shared by the entire system.
	input [3:0] address, //Address lines from the Avalon bus.
	input read, //Read request signal from the CPU. Used together with readdata
	input write,//Wrote request signal from the CPU. Used together with writedata
	input [15:0] writedata, //Data lines for the CPU to send data to the peripheral. 
									//Used together with write.
	output logic [15:0] out, //Data lines for the peripheral to return data to the CPU. Used
											//together with read.

	output logic ps2_done, //Signal to stall the Avalon bus when the peripheral is busy.
	inout PS2_CLK,
	inout PS2_DATA
);
	//TODO <UNIMPL>
	assign ps2_done = 1;
	assign out = 0; 
endmodule 