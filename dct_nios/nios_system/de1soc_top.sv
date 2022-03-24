module de1soc_top 
(
	// These are the inputs/outputs available on the DE1-SoC board.
	// Feel free to use the subset of these that you need -- unused pins will be ignored.
	// Please note that this project also specifies the correct board  
	// and loads the pin assignments so you do not need to worry about when using this kit. 
	
    // Clock pins
    input CLOCK_50,

    // Seven Segment Displays
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5,

    // Pushbuttons
    input [3:0] KEY,
	// Note that the KEYs are active low, i.e., they are 1'b1 when not pressed. 
	// So if you want them to be 1 when pressed, connect them as ~KEY[0].

    // LEDs
    output [9:0] LEDR,

    // Slider Switches
    input [9:0] SW
);
	
	// Declare the signals you need to connect the top level signals to your design. 	
	// data_out is a sample 4-bit signal to show how to connect to the LEDRs and HEX. 
	logic [3:0] data_out;
	
	// < Instantiate your module here> 	
	dct_nios u0 (
		.clk_clk (CLOCK_50)  // clk.clk
	);
	
		
	// Turn off HEXes you don't need
	assign HEX0 = '1;
	assign HEX1 = '1;
	assign HEX2 = '1;
	assign HEX3 = '1;
	assign HEX4 = '1;
	assign HEX5 = '1;
	
endmodule


