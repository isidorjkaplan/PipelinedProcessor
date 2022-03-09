module avalon_dct #(
    parameter MAX_SIZE=(1<<8), //the maximum size of an array that we can DCT
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
    parameter ADDR_START = 4'h0, ADDR_DATA = 4'h1, ADDR_SETQ=4'h3;
    
    integer size;    //goes up to max size for N, stores 
    integer term_num;
    integer M = 5;
    integer N;
    assign N = NBITS-1-M;
    logic cos_start;
    logic data_ready;
    integer PI;

 
    logic [NBITS-1:0] signal[MAX_SIZE];
    logic [NBITS-1:0] result[MAX_SIZE];
    logic [MAX_SIZE-1:0] result_valid;

    logic [NBITS-1:0] cos_in[MAX_SIZE];
    logic [NBITS-1:0] cos_out[MAX_SIZE];
    logic cos_done[MAX_SIZE];
    genvar i;
    generate
        for (i = 0; i < MAX_SIZE; i++) begin
            cos func(clk, reset, cos_in[i], M, cos_start && (i < size), cos_done[i], cos_out[i]);
        end
    endgenerate

    logic [NBITS-1:0] dct_term;
    integer K;
    logic all_cos_done;
    always_comb begin
        dct_term = 0;
        all_cos_done = 1;
        for (integer i = 0; i < MAX_SIZE; i++) begin
            cos_in[i] = 0;
        end
        for (integer i = 0; i < size; i++) begin
            cos_in[i] = (((PI/size)*(2*i + 1)*K) >> 1) % (2*PI); //mod by PI in Qmn format
            if (cos_in[i] > PI) begin
                cos_in[i] = cos_in[i] - PI;
            end
            dct_term = dct_term + ((cos_out[i]*cos_done[i]*signal[i]) >> N); //0 until done and then signal*cos
            all_cos_done = cos_done[i] & all_cos_done;
        end
    end

    typedef enum { IDLE, READY, WORKING, DONE } CosState;
    CosState cos_state;

    always_ff@(posedge clk, reset) begin
        if (reset) begin
            size <= 0;
            cos_start <= 0;
            K <= 0;
            data_ready <= 0;
            cos_state <= IDLE;
            result_valid <= 0;
            $display("DCT Reset");
        end
        else if (write && address == ADDR_SETQ) begin
            M <= writedata;
        end
        else if (write && address == ADDR_START) begin //initilize
            size <= writedata;
            term_num <= 0;
            K <= 0;
            cos_start <= 0;
            data_ready <= 0;
            cos_state <= IDLE;
            result_valid <= 0;
            $display("DCT: Size <= %d", writedata);

            PI <= $rtoi(3.14159265*(1<<N));
            $display("DCT: Q FORMAT M<=%d", writedata);
        end
        else if (write && address == ADDR_DATA && !data_ready) begin
            $display("DCT Write [%d] <= %f", K, $itor(writedata)/(1<<N));
            signal[K] <= writedata;
            K <= (K+1);
            //If this is the last item then the data is now ready
            if (K == size-1) begin
                data_ready <= 1;
                K <= 0;
                cos_state <= READY;
            end
        end
        else if (data_ready && K < size) begin
            if (cos_state == READY) begin
                cos_start <= 1;
                cos_state <= WORKING;
                //$display("DCT[%d]: Starting", K);
            end
            else if (cos_state == WORKING) begin
                cos_start <= 0;
                if (all_cos_done) begin
                    cos_state <= DONE;
                end
            end
            else if (cos_state == DONE) begin
                $display("DCT[%d] = %f", K,  $itor(dct_term)/(1<<N));
                K <= (K+1);
                result_valid[K] <= 1;
                result[K] <= dct_term;
                cos_state <= READY;
                for (integer i = 0; i < size; i++) begin
                    $display("Sin(%f)=%f", $itor($signed(cos_in[i]))/(1<<N), $itor($signed(cos_out[i]))/(1<<N));
                end
            end
        end
        //TODO: Upload data over N cycles
        //TODO: Once data is uploaded, itterate over size to get K terms one by one
        else begin
            
        end
    end

    assign out = read && (address < size) ? (result[address]) : 16'b0 ;
    assign done = !read || (address < size && result_valid[address]);
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