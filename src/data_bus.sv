module avalon_bus
(
    inout logic Clock, ReadData, WriteData, Reset,
    input logic [15:0] BusIn, DataAddr,

    output logic [15:0] BusOut,
    output logic DataDone,

    input logic [7:0] HEX[6], 
    input logic [9:0] SW,
    output logic [9:0] LEDR,
    output logic [3:0] KEY
);  
    parameter DEV_MEM = 4'h0, DEV_FP=4'h1;

    logic [3:0] device;

    /*Memory Controller*/
    logic [15:0] MemOut;
    inst_mem DataMem (DataAddr[11:0], Clock, BusIn, WriteData & (device==DEV_MEM), MemOut);
    logic mem_done;
    always_ff@(posedge Clock) begin
        if (Reset)
            mem_done <= 0;//not done
        else if (ReadData || WriteData) begin
            mem_done <= ~mem_done;//on the clock edge it becomes done
        end
        else begin
            mem_done <= 0;//if not attempting to write then not done
        end
    end
    

    /*Floating Point Unit*/
    logic [15:0] FpOut;    
    logic fp_waitreq;
    avalon_fp_mult fp_mult(Clock, Reset, DataAddr[2:0], ReadData & (device==DEV_FP), WriteData & (device == DEV_FP), BusIn, FpOut, fp_waitreq);

    /*Multiplexer for the output logic*/
    always_comb begin
        device = DataAddr[15:12];
        case(device)
            DEV_MEM:begin
                DataDone=mem_done; //memory is single-cycle
                BusOut=MemOut;
            end
            DEV_FP:begin
                DataDone=~fp_waitreq;
                BusOut=FpOut;
            end
        endcase
    end

endmodule