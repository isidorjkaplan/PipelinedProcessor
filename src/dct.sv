module avalon_dct #(
    parameter MAX_SIZE=(1<<8), //the maximum size of an array that we can DCT
    parameter NBITS=16,
    parameter PREC=64
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
    integer M;
    integer N;
    assign N = NBITS-1-M;
    logic data_ready;

 
    logic signed [NBITS-1:0] signal[MAX_SIZE];
    logic signed [NBITS-1:0] result[MAX_SIZE];
    logic [MAX_SIZE-1:0] result_valid;

    parameter COS_TERMS=2*MAX_SIZE;
    logic signed [NBITS-1:0] cos_q15[COS_TERMS];

    genvar i; 
    generate
        assign cos_q15[0] = 16'b0111111111111111; //have to hard code this to avoid overflow
        for (i = 1; i < COS_TERMS; i++) begin
            real real_cos_in = $cos(3.14159265*i/MAX_SIZE);
            assign cos_q15[i] = $rtoi(real_cos_in*(1<<(NBITS-1)));
        end
    endgenerate

    integer signed dct_term;
    integer signed dct_terms[MAX_SIZE];
    integer K;
    integer cos_index;
    always_comb begin
        dct_term = 0;
        for (integer n = 0; n < MAX_SIZE; n++) begin
            dct_terms[n] = 0;
        end
        for (integer n = 1; n <= size-2; n++) begin
            dct_terms[n] = signal[n]*cos_q15[(n * K * MAX_SIZE / (size-1)) % COS_TERMS];
            dct_term += dct_terms[n];
            //$display("Index: %d, Term: %d", (n * K * MAX_SIZE / (size-1)) % COS_TERMS, dct_terms[n]);
        end
        dct_term /= (1<<(NBITS-1));
        dct_term += signal[0]/2;
        if (K % 2 == 0)
            dct_term += signal[size-1]/2;
        else 
            dct_term -= signal[size-1]/2;
    end

    always_ff@(posedge clk, reset) begin
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
            size <= writedata;
            K <= 0;
            data_ready <= 0;
            result_valid <= 0;
            $display("DCT: Size <= %d", writedata);            
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