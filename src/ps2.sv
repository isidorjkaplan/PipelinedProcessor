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
	input PS2_CLK,
	input PS2_DATA
);
	logic [8:0] buffer;
	logic idle;
	logic valid;
	logic pairity_bit;
	integer bits_read = 0;
	
	parameter NUM_BYTES=3;
	logic [8:0] bytes[NUM_BYTES];

	
	always_ff@(posedge PS2_CLK, posedge reset) begin
		if (reset) begin
			bits_read <= 0;
			idle <= 1;
			valid <= 0;
			buffer <= 0;
			for (integer i =0 ; i < NUM_BYTES; i++) begin
				bytes[i] <= 0;
			end
		end
		else if (idle) begin //this is the start of a new transmission
			idle <= 0;
			bits_read <= 0;
		end
		else if (bits_read <= 8) begin //goes equal to 8 since we have a pairity bit as the 9th bit
			buffer[bits_read] <= PS2_DATA;//read data into buffer
			bits_read <= (bits_read + 1); //increment bits read
		end
		else begin //this is the stop command
			idle <= 0;
			bits_read <= 0;
			valid <= ^buffer; //XOR reduction. Must have even pairity to be valid
			//update the "bytes" with the latest data
			for (integer i = 0; i < NUM_BYTES-1; i++) begin
				bytes[i] <= bytes[i+1];
			end
			bytes[NUM_BYTES-1] <= buffer;
		end
	end
	
	assign ps2_done = idle; //only valid if currently idle
	always_comb begin
		out = 0;
		if (address < NUM_BYTES) begin
			out = bytes[address];
		end	
	end
	 
endmodule 