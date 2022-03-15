
module avalon_dct_nios
(
	input clk, //Common clock shared by the entire system.
	input reset, //Common reset shared by the entire system.
	input [7:0] avs_s1_address, //Address lines from the Avalon bus.
	input avs_s1_read, //Read request signal from the CPU. Used together with readdata
	input avs_s1_write,//Wrote request signal from the CPU. Used together with writedata
	input [31:0] avs_s1_writedata, //Data lines for the CPU to send data to the peripheral. 
									//Used together with write.
	output logic [31:0] avs_s1_readdata, //Data lines for the peripheral to return data to the CPU. Used
											//together with read.

	output logic avs_s1_waitrequest //Signal to stall the Avalon bus when the peripheral is busy.
);
    avalon_dct (clk, reset, avs_s1_address, avs_s1_read, avs_s1_write, avs_s1_writedata, avs_s1_readdata, ~avs_s1_waitrequest);
endmodule


module avalon_dct #(
    parameter MAX_SIZE=64, //the maximum size of an array that we can DCT
    parameter HEIGHT = $clog2(MAX_SIZE),
    parameter NBITS=16,
    parameter NUM_TERMS_PER_CYCLE=8//number of multiply-accumulates per cycle
)
(
	input clk, //Common clock shared by the entire system.
	input reset, //Common reset shared by the entire system.
	input [7:0] address, //Address lines from the Avalon bus.
	input read, //Read request signal from the CPU. Used together with readdata
	input write,//Wrote request signal from the CPU. Used together with writedata
	input signed [NBITS-1:0] writedata, //Data lines for the CPU to send data to the peripheral.
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

    parameter COS_TERMS=MAX_SIZE << 1;
    logic signed [NBITS-1:0] cos_q15[COS_TERMS];

    dct_rom cos_terms_rom(cos_q15[0:MAX_SIZE]);
    // set rest of the cosing terms
    genvar cos_position;
    generate
        for(cos_position = MAX_SIZE+1; cos_position < COS_TERMS; cos_position++) begin : set_cos_q15
            assign cos_q15[cos_position] = cos_q15[COS_TERMS-cos_position];
        end
    endgenerate

    integer signed dct_term_latch;
    integer signed dct_term_comb;
    integer K;
    integer cos_pos_start;
    integer signed cos_term_value;
    integer n;
    always_comb begin
        dct_term_comb = 0;
        cos_term_value = 0;
        n = 0;
        if (data_ready) begin
            //calculate the actual sum of dct terms to add
            for (integer pos = 0; pos < NUM_TERMS_PER_CYCLE; pos++) begin
                n = cos_pos_start + pos;
                //calculate the term to add
                if (n <= size-1 && n < MAX_SIZE && n >= 0) begin
                    cos_term_value = signal[n]*cos_q15[(((2*n+1) * K * MAX_SIZE) >> (power+1)) & (COS_TERMS - 1)] >>> (NBITS-1);
                    //$display("DCT_COMB: Adding n=%d = sig[n]*cos[%d] = %f", n, ((n * K * MAX_SIZE) >> power) & (COS_TERMS - 1), $itor(cos_term_value)/(1<<N));
                end else 
                    cos_term_value = 0;
                //add it to the comb
                dct_term_comb += cos_term_value;
            end
            dct_term_comb += dct_term_latch;
        end
    
    end

    always_ff@(posedge clk, posedge reset) begin
        if (reset) begin
            size <= 0;
            K <= 0;
            data_ready <= 0;
            result_valid <= 0;
            cos_pos_start <= 0;
            dct_term_latch <= 0;
            $display("DCT Reset");
        end
        else if (write && address == ADDR_SETQ) begin
            M <= writedata;
            $display("DCT: Q FORMAT M<=%d", writedata);
        end
        else if (write && address == ADDR_START) begin //initilize
            size <= 1<<writedata;
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
                cos_pos_start <= 0;//we start from beginning of signal
                dct_term_latch <= 0;//no calculated DCT term so far
            end
        end
        else if (data_ready && K < size) begin
            //still calculatnig the current set of terms
            if (cos_pos_start < size) begin
                dct_term_latch <= dct_term_comb;
                cos_pos_start <= (cos_pos_start + NUM_TERMS_PER_CYCLE);//advance start
            end
            //we have fully calculated the dct_term_latch
            else begin
                $display("DCT[%d] <= %f", K, $itor(dct_term_latch)/(1<<N));
                result[K] <= dct_term_latch;
                result_valid[K] <= 1;
                K <= (K+1);
                cos_pos_start <= 0;
                dct_term_latch <= 0;
            end
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
