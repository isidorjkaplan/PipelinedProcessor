
module avalon_fp_mult
(
	input clk, //Common clock shared by the entire system.
	input reset, //Common reset shared by the entire system.
	input [2:0] avs_s1_address, //Address lines from the Avalon bus.
	input avs_s1_read, //Read request signal from the CPU. Used together with readdata
	input avs_s1_write,//Wrote request signal from the CPU. Used together with writedata
	input [15:0] avs_s1_writedata, //Data lines for the CPU to send data to the peripheral. 
									//Used together with write.
	output logic [15:0] avs_s1_readdata, //Data lines for the peripheral to return data to the CPU. Used
											//together with read.

	output logic avs_s1_waitrequest //Signal to stall the Avalon bus when the peripheral is busy.
);
	// 1. Create the signals to connect to the AVS peripheral registers. 
	logic [15:0] op1, op2, result, op1_reg, op2_reg;
	logic nan, overflow, underflow, zero;
	logic [3:0] waiting_cycles;
	assign fp_en = waiting_cycles > 0;//enable if op in progress
	logic [2:0] status;
	//if we are busy and someone tries to perform an operation, we signify to wait until we are done
	
	parameter addr_op1 = 3'b000   ;
	parameter addr_op2 = 3'b001   ;
	parameter addr_s = 3'b010   ;
	parameter addr_res = 3'b011   ;
	parameter addr_status = 3'b100   ;

	always_comb begin
		/*Assign the status*/
		status = 3'h0;
		if (overflow)
			status = 3'h1;
		if (underflow)
			status = 3'h2;
		if (zero)
			status = 3'h3;
		if (nan)
			status = 3'h4;

		/*Assign the waitreq*/
		avs_s1_waitrequest = 0;
		if (fp_en) begin
			if (avs_s1_write) begin
				//Assume we cannot write to registers (including op1/op2) until fp is done
				//TODO Double check this, may allow writing to op1/op2 but not s
				avs_s1_waitrequest = 1;
			end
			else if (avs_s1_read) begin
				case (avs_s1_address)
					//If reading op1/op2/s then can fetch even during fp execution
					addr_op1: avs_s1_waitrequest = 0;
					addr_op2: avs_s1_waitrequest = 0;
					addr_s: avs_s1_waitrequest = 0;
					//To get the results must wait for it to finish
					addr_res: avs_s1_waitrequest = 1;
					addr_status: avs_s1_waitrequest = 1;
				endcase
			end
		end
	end
	
	parameter FP_LAT = 3;
	fp_mult_lab4 #(.E(8), .M(7)) fpm
	(
		//.clk_en(fp_en) ,		
		//.clock(clk) ,				
		.X(op1_reg) ,			
		.Y(op2_reg) ,			
		.nan(nan) ,			
		.overflow(overflow) ,	
		.result(result) ,			
		.underflow(underflow) ,
		.zero(zero) 			
	);

	/* 3. Write code to handle the read and write operations.
		  It is best to start with write. Using the module signals,
		  you should determine when a write operation occurs and what 
		  register is being written to. 
	*/
	
	// Avalon write
	always_ff @ (posedge clk or posedge reset) begin
		if (reset) begin
			// Make sure to reset all your signals.// Make sure to reset all your signals.
			op1 <= 0;
			op2 <= 0;
			waiting_cycles = 0;
		end
		else if (waiting_cycles > 0) begin
			//decrement one more waiting cycle
			waiting_cycles = waiting_cycles - 1;
		end
		/*Only consider a write if not currently busy*/
		else if (avs_s1_write) begin
			case (avs_s1_address)
				addr_op1: op1 <= avs_s1_writedata;
				addr_op2: op2 <= avs_s1_writedata;
				addr_s: begin
					if (avs_s1_writedata) //if it is 1 then we start
						waiting_cycles <= FP_LAT;
                    op1_reg <= op1;//put the input at the fp unit
                    op2_reg <= op2;//put the input at the fp unit
				end
			endcase
		end
	end

	/* 4. Now write the code for a read operation. 
		  This should be much simpler than write as 
		  you should just need a single mux. 
    */
	always_comb begin
		//Not synchronus. Just a mux on the other registers. 
		//Since registers only update on clock edge this is, in effect, synchronous
		avs_s1_readdata = 0;
		if (avs_s1_read)
			case (avs_s1_address)
				addr_op1: avs_s1_readdata = op1;
				addr_op2: avs_s1_readdata = op2;
				addr_s: avs_s1_readdata = fp_en;
				addr_res: avs_s1_readdata = result;
				addr_status: avs_s1_readdata = status;
			endcase	
	end

	
	/* 5. It is best to deal with the single cycle case first and then
	change your design to work with waitrequest. 
	*/


endmodule
 
 
 
 module fp_mult_lab4 #(
    parameter E = 8 , // Number of bits in the Exponent
    parameter M = 23 , // Number of bits in the Mantissa
    parameter BITS = 1 + E + M/* TODO */ , // Total number of bits in the floating point number
    parameter EB = (1<<(E-1))-1,/* TODO */ // Value of the bias , based on the exponent .
    parameter MAXEXP = 2*EB+1
)(
    input [ BITS - 1:0] X,
    input [ BITS - 1:0] Y,
    output [ BITS - 1:0] result,
    output zero , underflow , overflow , nan
);
    //Define x wires
    logic sign_x;
    logic [E-1:0] exp_x;
    logic [M-1:0] mant_x;
    //assign x wires
    assign sign_x= X[BITS-1];
    assign exp_x = X[BITS-2:M];
    assign mant_x = X[M-1:0];

    //define y wires
    logic sign_y;
    logic [E-1:0] exp_y;
    logic [M-1:0] mant_y;
    //asign y wires
    assign sign_y = Y[BITS-1];
    assign exp_y = Y[BITS-2:M];
    assign mant_y = Y[M-1:0];

    //TODO REST

    //Define other misc wires
    logic sign_res;//sign bit
    logic [E-1:0] exp_res;//exponent
    logic [M+1:0] mant_res;//mantisa
    assign result = {sign_res, exp_res, mant_res[M-1:0]}; //actually put together the result

    //local flags and temp variables
    logic tmp_overflow;
    assign overflow=tmp_overflow;
    logic tmp_underflow;
    assign underflow=tmp_underflow;
    logic tmp_zero;
    assign zero=tmp_zero;
    logic tmp_nan;
    assign nan=tmp_nan;
    logic shift;

    logic [M+1:0] mant_tmp; //temporary variable to work with
    logic [2*M+1:0] mant_prod;

    //the combinational block handling most of the actual logic
    always_comb begin
        //initilize flags to zero
        tmp_zero = 1'b0;
        tmp_overflow = 1'b0;
        tmp_underflow = 1'b0;
        tmp_nan = 1'b0;
        //Calcualte the resulting sign bit
        sign_res = sign_x ^ sign_y;
        //calculate the new mantisa
        mant_prod = {1'b1, mant_x} * {1'b1, mant_y}; //multiply with hidden values and truncate lower bits
        mant_tmp = mant_prod[2*M+1:M];
        shift = mant_tmp[M+1];
        //handle the shifting if the value is now greater then 1
        exp_res = exp_x + exp_y + shift - EB;
        mant_res = shift?(mant_tmp>>1):mant_tmp;
        //assert(mant_res[M+1:M] == 2'b01);

        //HANDLE CORNER CASES

        //NAN takes precedence over 0
        if ((exp_x==MAXEXP && mant_x !== 0) || (exp_y==MAXEXP && mant_y !== 0)) begin
            tmp_nan = 1'b1;
            //set the output to zero
            //sign_res = 0;
            exp_res = MAXEXP;
            //mant_res = 0;
        end
        //corner case, one of the inputs is zero
        //NOTE: I am treating subnormalized numbers as being zero. We were not required to handl ethem
        //      This is why i commented out the mant_x and mant_y, those being nonzero are subnormalized
        else if ((exp_x == 0 && mant_x == 0) || (exp_y == 0 && mant_y == 0)) begin
            tmp_zero = 1'b1;
            //set the output to zero
            sign_res = 0;
            exp_res = 0;
            mant_res = 0;
        end
        // for actual underflows
        else if ((exp_x == 0) || (exp_y == 0)) begin
            tmp_underflow = 1;
            exp_res = 0;
            mant_res = 1;//we keep the mantisa for underflows, rest stays zero (Albert: i think setting it to 1 is safer)
        end
        else if (exp_x + exp_y + shift <= EB) begin
            tmp_underflow = 1;
            mant_res = 1;//we keep the mantisa for underflows, rest stays zero (Albert: i think setting it to 1 is safer)
            //set the output to zero
            //sign_res = 0;
            exp_res = 0;
        end //overflow may have been trigerred earlier so we check the flag
        else if (exp_x + exp_y + shift - EB >= MAXEXP || exp_x==MAXEXP || exp_y==MAXEXP) begin
            tmp_overflow = 1'b1;
            //set the output to zero
            //sign_res = 0;
            exp_res = MAXEXP;
            mant_res = 0;
        end
        //assert (mant_res[24:23] == 2'b01); //this is garunteed otherwsie error. Must have hidden one
    end

endmodule