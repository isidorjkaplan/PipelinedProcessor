module avalon_bus(
    inout logic Clock, ReadData, WriteData, Reset,
    input logic [15:0] BusIn, DataAddr,
    output logic [15:0] BusOut,
    output logic Waitreq
);  


    parameter DEV_MEM = 4'h0, DEV_FP=4'h1;

    logic [3:0] device;

    logic [15:0] MemOut;
    inst_mem DataMem (DataAddr[11:0], Clock, BusIn, WriteData & (device==DEV_MEM), MemOut);

    /*module avalon_fp_mult
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
);*/
    logic [15:0] FpOut;    
    logic fp_waitreq;
    avalon_fp_mult fp_mult(Clock, Reset, DataAddr[2:0], ReadData & (device==DEV_FP), WriteData & (device == DEV_FP), BusIn, FpOut, fp_waitreq);

    always_comb begin
        device = DataAddr[15:12];
        case(device)
            DEV_MEM:begin
                Waitreq=0; //memory is single-cycle
                BusOut=MemOut;
            end
            DEV_FP:begin
                Waitreq=fp_waitreq;
                BusOut=FpOut;
            end
        endcase
    end

    /*
    logic [3:0] waiting_cycles;
    always_ff@(posedge CLOCK, posedge Reset) begin
        if (Reset)
            waiting_cycles <= 0;
        else if (waiting_cycles > 0)
            waiting_cycles <= waiting_cycles-1; //decrement waiting cycles
        else if (waiting_cycles == 0 && (WriteData || ReadData))
            waiting_cycles <= 1; //reset the waiting cycles, started a new operation
    end
    assign DataDone = waiting_cycles==0;*/

endmodule