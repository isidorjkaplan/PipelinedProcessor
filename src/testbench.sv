
`timescale 1ns/1ns
module tb();
    logic ResetN, Clock;
    //Initilize the DUT
    logic [6:0] HEX[6];
    logic [9:0] LEDR;
    logic [3:0] KEY;
    de1soc_top dut(.CLOCK_50(Clock), .HEX0(HEX[0]), .HEX1(HEX[1]), .HEX2(HEX[2]), .HEX3(HEX[3]), .HEX4(HEX[4]), .HEX5(HEX[5]), .KEY(KEY), .LEDR(LEDR), .SW(10'h0));
    
    assign #10 Clock = (~Clock & ResetN);
    assign KEY[3] = ResetN;
    assign KEY[2:0] = 3'h0;


    initial begin
        ResetN = 0;
        #15
        ResetN = 1;
        for (integer i = 0; i < 10000; i++) begin
            @(posedge Clock);
            if (dut.WriteData && (dut.DataAddr == 16'hffff)) begin
                $display("Processor sent kill command");
                $display("CPI: %g\n", real'(dut.proc.num_cycles) / dut.proc.num_instr);
                $stop();
            end
        end
        $stop();
    end


endmodule