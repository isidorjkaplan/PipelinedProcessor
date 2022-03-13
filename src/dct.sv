module avalon_dct #(
    parameter MAX_SIZE=128, //the maximum size of an array that we can DCT
    parameter HEIGHT = $clog2(MAX_SIZE),
    parameter NBITS=16
)
(
	input clk, //Common clock shared by the entire system.
	input reset, //Common reset shared by the entire system.
	input [7:0] address, //Address lines from the Avalon bus.
	input read, //Read request signal from the CPU. Used together with readdata
	input write,//Wrote request signal from the CPU. Used together with writedata
	input [NBITS-1:0] writedata, //Data lines for the CPU to send data to the peripheral.
									//Used together with write.
	output logic [NBITS-1:0] out, //Data lines for the peripheral to return data to the CPU. Used
											//together with read.
	output logic done //Signal to stall the Avalon bus when the peripheral is busy.
);
    //IDLE, can accept requests, COS=Calculating cosine terms for this N, DCT=doing DCT
    parameter ADDR_START = 4'h0, ADDR_DATA = 4'h1, ADDR_SETQ=4'h2;

    integer size;
    logic [2:0] power;
    integer M;
    integer N;
    assign N = NBITS-1-M;
    logic data_ready;


    logic signed [NBITS-1:0] signal[MAX_SIZE];
    logic signed [NBITS-1:0] result[MAX_SIZE];
    logic [MAX_SIZE-1:0] result_valid;

    parameter COS_TERMS=2*MAX_SIZE;
    logic signed [NBITS-1:0] cos_q15[COS_TERMS];

    dct_rom cos_terms_rom(cos_q15[0:128]);
    // set rest of the cosing terms
    genvar cos_position;
    generate
        for(cos_position = 129; cos_position < COS_TERMS; cos_position++) begin : set_cos_q15
            assign cos_q15[cos_position] = cos_q15[COS_TERMS-cos_position];
        end
    endgenerate

    integer signed dct_term;
    integer signed dct_term_intermediate[HEIGHT:0][MAX_SIZE-1:0];
    integer signed dct_terms[MAX_SIZE];
    integer K;
    integer cos_index;
    always_comb begin
        // dct_term = 0;
        for (integer n = 0; n < MAX_SIZE; n++) begin
            dct_terms[n] = 0;
        end
        for (integer n = 1; n <= size-2 && n < MAX_SIZE; n++) begin
            dct_terms[n] = signal[n]*cos_q15[((n * K * MAX_SIZE) >> power) & (COS_TERMS - 1)];
            // dct_term += dct_terms[n];
            //$display("Index: %d, Term: %d", (n * K * MAX_SIZE / (size-1)) % COS_TERMS, dct_terms[n]);
        end
        dct_term = dct_term_intermediate[0][0];
        dct_term = dct_term >>> (NBITS-1);
        dct_term += signal[0]>>>1;

        if(K & 1)
            dct_term -= signal[size-1]>>>1;
        else
            dct_term += signal[size-1]>>>1;
    end

    genvar row;
    genvar column;
    // adder tree for dct_term (the sum of all dct_terms)
    generate
        for(column = 0; column < MAX_SIZE; column++)begin : initiate_tree
            assign dct_term_intermediate[HEIGHT][column] = dct_terms[column];
        end
        for(row = HEIGHT-1; row >= 0; row--)begin : c
            parameter width = 1<<row;
            for(column = 0; column < width; column++)begin : r
                assign dct_term_intermediate[row][column] = dct_term_intermediate[row+1][column<<1] + dct_term_intermediate[row+1][(column<<1)+1];
            end
        end
    endgenerate

    always_ff@(posedge clk, posedge reset) begin
        if (reset) begin
            size <= 0;
            K <= 0;
            data_ready <= 0;
            result_valid <= 0;
            $display("DCT Reset");
        end
        else if (write && address == ADDR_SETQ) begin
            M <= writedata;
            $display("DCT: Q FORMAT M<=%d", writedata);
        end
        else if (write && address == ADDR_START) begin //initilize
            size <= 2**writedata;
            power <= writedata;
            K <= 0;
            data_ready <= 0;
            result_valid <= 0;
            $display("DCT: Size <= %d", 2**writedata);
        end
        else if (write && address == ADDR_DATA && !data_ready) begin
            $display("DCT Write [%d] <= %f", K, $itor(writedata)/(1<<N));
            signal[K] <= writedata;
            K <= (K+1);
            //If this is the last item then the data is now ready
            if (K == size-1) begin
                data_ready <= 1;
                K <= 0;
            end
        end
        else if (data_ready && K < size) begin
            $display("DCT[%d] <= %f", K, $itor(dct_term)/(1<<N));
            result[K] <= dct_term;
            result_valid[K] <= 1;
            K <= (K+1);
        end
    end

    assign out = read && (address < size) ? (result[address]) : 16'b0 ;
    assign done = !read || address >= size || result_valid[address];
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
