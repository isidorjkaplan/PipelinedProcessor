`timescale 1ns/1ns
parameter NBITS=16;
module testbench_dct();
    logic ResetN, Clock;
    logic signed [NBITS-1:0] x;
    integer M; //the integer part of the number, fixed point
    integer N;
    assign N = NBITS-1-M;
    logic start;
    logic done;
    logic [NBITS-1:0] result;
    real real_input;

    cos dut_cos(Clock, ~ResetN, x, M, start, done, result);

    logic [7:0] addr;
    logic read, write, dct_done;
    logic [NBITS-1:0] dct_out;
    integer test_size ;
    avalon_dct dut_dct(Clock, ~ResetN, addr,  read, write, x, dct_out, dct_done);

    assign #10 Clock = (~Clock & ResetN);

    initial begin
        read = 0;
        write = 0;
        addr = 0;
        ResetN = 0;
        #15
        ResetN = 1;
        start = 0;
        #15
        M = 6;
        /*
        $display("Cosine Unit Test");
        for (integer i = 0; i < 10; i++) begin
            start = 1;
            real_input = 3.14159265 * i/10;
            x = $rtoi(   (real_input*(1<<N)   )); //Gets it as an integer
            @(posedge Clock);
            start = 0;
            while (!done) begin
                @(posedge Clock);
            end
            $display("Cos(%f)=%f", real_input, $itor($signed(result))/(1<<N));
        end*/

        @(posedge Clock);

        x = M;
        addr = 2;
        write = 1;
        @(posedge Clock)
        test_size = 5;
        x = test_size;
        addr = 0;
        $display("TB Writing %d for size when test size is%d", 2**test_size, test_size);
        @(posedge Clock);
        addr = 1;

        for (integer i = 0; i < 2**test_size; i++) begin
            real_input = 8*$cos(3.14159265 * i/(2**test_size));
            //real_input = 1;

            x = $rtoi(   (real_input*(1<<N)   )); //Gets it as an integer
            //$display("TB Writing %f", real_input);
            @(posedge Clock);
        end
        write = 0;
        addr = 0;
        read = 1;
        @(posedge Clock);
        for (integer i = 0; i < 2**test_size; i++) begin
            while (!dct_done) begin
                @(posedge Clock);
            end
            //$display("TB DCT[%d] = %f", addr, $itor($signed(dct_out))/(1<<N));
            addr = addr + 1;
            @(posedge Clock);
        end



        $stop();
    end
endmodule
