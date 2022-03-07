module avalon_dct
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
	output logic done //Signal to stall the Avalon bus when the peripheral is busy.
);


endmodule


//Assumes that input is between 0 and pi, error blows up after that
//ignores the sign, only works with unsigned
module cos #(
    parameter TERMS = 5, //the number of expansion terms
    parameter NBITS=16
)(
    input logic Clock,
    input logic Reset,
    input logic [NBITS-1:0] x,
    input integer M, //the integer part of the number, fixed point
    input logic start,
    output logic done,
    output logic [NBITS-1:0] result
);
    logic [NBITS-1:0] i;
    integer N;
    assign N = NBITS-1-M;

    integer denom;
    integer powx;
    integer value;
    integer x2;
    integer pos_x; //x but made positive

    integer next_powx;
    integer next_denom;
    integer next_term;
    integer next_value;

    logic valid = 0;

    always_comb begin
        if (x[NBITS-1] < 0)
            pos_x = -x;
        else
            pos_x = x;
        next_powx = (powx * x2) >> N;
        next_denom = (2*i)*(2*i-1)*denom;
        next_term = next_powx / next_denom;
        if (i[0]) begin//if odd
            next_value = value - next_term;
        end
        else begin
            next_value = value + next_term;
        end
    end

    always_ff@(posedge Clock, posedge Reset) begin
        if (start || Reset) begin
            i <= 1;
            value <= (1<<N);
            denom <= 1;
            powx <= 1<<N;
            x2 <= (pos_x*pos_x) >> N; //x**2
            //$display("x=%f, pos_x=%f, x2=%f", $itor(x)/(1<<N),$itor(pos_x)/(1<<N), $itor(x2)/(1<<N));
        end
        else if (i < TERMS) begin
            //$display("%d: powx=%f, denom=%d, term=%f, value=%f", i, $itor(next_powx)/(1<<N), next_denom, $itor(next_term)/(1<<N), $itor(next_value)/(1<<N));
            powx <= next_powx;
            denom <= next_denom;
            value <= next_value;
            i <= (i+1);
        end
    end
    assign result = value;
    assign done = (i==TERMS) && !start; //if we just started not ready

endmodule