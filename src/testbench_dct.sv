`timescale 1ns/1ns
parameter NBITS=16;
module testbench_dct();
    logic ResetN, Clock;
    logic [NBITS-1:0] x;
    integer M; //the integer part of the number, fixed point
    integer N;
    assign N = NBITS-1-M;
    logic start;
    logic done;
    logic [NBITS-1:0] result;
    real real_input;

    cos dut_cos(Clock, ~ResetN, x, M, start, done, result);
    
    assign #10 Clock = (~Clock & ResetN);

    initial begin
        ResetN = 0;
        #15
        ResetN = 1;
        start = 0;
        #15
        M = 6;
        for (integer i = 0; i < 10; i++) begin
            start = 1;
            real_input = 3.14159265 * i/10;
            x = $rtoi(   (real_input*(1<<N)   )); //Gets it as an integer
            @(posedge Clock);
            start = 0;
            while (!done) begin
                @(posedge Clock);
            end
            $display("Sin(%f)=%f", real_input, $itor($signed(result))/(1<<N));
        end
        $stop();
    end
endmodule