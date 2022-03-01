
`timescale 1ns/1ns
module tb();
    logic ResetN, Clock;
    //Initilize the DUT
    logic [6:0] HEX[6];
    logic [9:0] LEDR;
    de1soc_top dut(Clock, HEX[0], HEX[1], HEX[2], HEX[3], HEX[4], HEX[5], {ResetN, 3'h0}, LEDR, 10'h0);
    
    assign #10 Clock = (~Clock & ResetN);

    initial begin
        ResetN = 0;
        #15
        ResetN = 1;
        for (integer i = 0; i < 10000; i++) begin
            @(posedge Clock);
            if (dut.WriteData && (dut.DataAddr == 16'hffff)) begin
                $display("Processor sent kill command");
                $stop();
            end
        end
        $stop();
    end


endmodule