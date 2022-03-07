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
	logic [2:0] data;
	logic [3:0] x;
	logic [3:0] y;
	assign out = {4'b0, x, y, data};
	assign ps2_done = 1;
	
	ps2_mouse #(
			.WIDTH(10),
			.HEIGHT(10),
			.BIN(100),
			.HYSTERESIS(30))
	U1(
			.start(reset),  
			.reset(reset),  
			.CLOCK_50(clk),  
			.PS2_CLK(PS2_CLK), 
			.PS2_DAT(PS2_DATA), 
			.button_left(data[0]),  
			.button_right(data[1]),  
			.button_middle(data[2]),  
			.bin_x(x),
			.bin_y(y)
			);
	 
endmodule 