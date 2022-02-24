module avalon_bus(
    inout logic Clock, ReadData, WriteData,
    input logic [15:0] BusIn, DataAddr,
    output logic [15:0] BusOut,
    output logic Waitreq
);  
    parameter DEV_MEM = 4'h0, DEV_FP;

    logic [3:0] device;

    logic [15:0] MemOut;
    inst_mem DataMem (DataAddr[11:0], Clock, BusIn, WriteData & (device==DEV_MEM), MemOut);


    always_comb begin
        device = DataAddr[15:12];
        case(device)
            DEV_MEM:begin
                Waitreq=0; //memory is single-cycle
                BusOut=MemOut;
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