
 module fp_adder #(
    parameter E = 8 , // Number of bits in the Exponent
    parameter M = 23 , // Number of bits in the Mantissa
    parameter BITS = 1 + E + M/* TODO */ , // Total number of bits in the floating point number
    parameter EB = (1<<(E-1))-1,/* TODO */ // Value of the bias , based on the exponent .
    parameter MAXEXP = 2*EB+1
)(
    input [ BITS - 1:0] X,
    input [ BITS - 1:0] Y,
    output [ BITS - 1:0] result,
    output logic zero , underflow , overflow , nan
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

    //Define other misc wires
    logic sign_res;//sign bit
    logic [E-1:0] exp_res;//exponent
    logic [M:0] mant_res;//mantisa
    assign result = {sign_res, exp_res, mant_res[M-1:0]}; //actually put together the result
    
    logic sign_min;
    logic [E-1:0] exp_min;
    logic [M-1:0] mant_min;

    logic sign_max;
    logic [E-1:0] exp_max;
    logic [M-1:0] mant_max;

    logic [E:0] mant_min_shift;
    logic shift;

    //the combinational block handling most of the actual logic
    always_comb begin
        if (exp_x > exp_y) begin
            sign_min = sign_y;
            exp_min = exp_y;
            mant_min = mant_y;
            sign_max = sign_x;
            exp_max = exp_x;
            mant_max = mant_x;
        end
        else begin
            sign_min = sign_x;
            exp_min = exp_x;
            mant_min = mant_x;
            sign_max = sign_y;
            exp_max = exp_y;
            mant_max = mant_y;
        end
        mant_min_shift = ({1'b1, mant_min} >> (exp_max-exp_min));
        underflow = exp_max-exp_min >= E; //if this is the case then the additon cannot occur anymore
        exp_res = exp_max;
        if (sign_min == sign_max) begin
            sign_res = sign_min; //wont change sign
            //note that mant_res includes the implicit 1
            //if the number was too big the two implicit ones add and overflow
            {shift, mant_res} = {1'b1, mant_max} + mant_min_shift;
            if (shift) begin
                exp_res = exp_res + 1; //when we add if overflow then exponent goes up by 1
                mant_res = {1'b1, mant_res} >> 1; //on overflow we have to to the right to divide mantisa
            end
        end
        //This is more complicated. Could have exponent go down by a lot
        else if (sign_min != sign_max) begin
            if (mant_max >= mant_min_shift) begin
                mant_res = {1'b1, mant_max} - mant_min_shift;
            end
            else begin

            end

            shift = 1;
            for (integer i = E; i >= 0 && shift; i--) begin
                shift = !mant_res[E];
                if (shift) begin
                    exp_res = exp_res - 1;
                    mant_res = mant_res << 1;
                end
            end
            if (shift) begin
                zero = 1; //raise zero flag. Two values were the same
            end
        end
    end

endmodule