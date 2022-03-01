module avalon_bus
(
    inout logic Clock, ReadData, WriteData, Reset,
    input logic [15:0] BusIn, DataAddr,

    output logic [15:0] BusOut,
    output logic DataDone,

    output logic [6:0] HEX[6], 
    input logic [9:0] SW,
    output logic [9:0] LEDR,
    input logic [3:0] KEY
);  
    parameter DEV_MEM = 4'h0, DEV_FP=4'h1, DEV_HEX=4'h2, DEV_SW=4'h3, DEV_LEDR=4'h4, DEV_KEY=4'h5;

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

    /*Controllers for HEX/SW/LEDR/KEY*/
    logic [6:0] hex_reg[6];
    logic [9:0] ledr_reg;
 
    always_ff@(posedge Clock, posedge Reset) begin
        if (Reset) begin
            for (integer i = 0; i < 6; i++)
                hex_reg[i] <= 0;
            ledr_reg <= 0;
        end
        else if (device == DEV_HEX && DataAddr[2:0] < 6) begin
            hex_reg[DataAddr[2:0]] <= BusIn[7:0];
        end
        else if (device == DEV_LEDR) begin
            ledr_reg <= BusIn[9:0];
        end
    end
    assign HEX = hex_reg;
    assign LEDR = ledr_reg;
    

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
            DEV_SW:begin
                DataDone=1;//data is done immediately
                BusOut={5'h0, SW};
            end
            DEV_KEY:begin
                DataDone=1;//data is done immediately
                BusOut={11'h0, KEY};
            end
            default:begin
                DataDone=1;
                BusOut=0;
            end
        endcase
    end

endmodule