module avalon_bus
(
    inout logic Clock, ReadData, WriteData, Reset,
    input logic [15:0] BusIn, DataAddr,

    output logic [15:0] BusOut,
    output logic DataDone,

    output logic [6:0] HEX[6], 
    input logic [9:0] SW,
    output logic [9:0] LEDR,
    input logic [3:0] KEY,
    input wire IRDA_RXD, //IR reciever wire
    output wire IRDA_TXD, //IR emitter wire
    inout PS2_CLK,
    inout PS2_DATA
);  
    //0xABCD -> A selects primary device., B selects secondary device if applicable

    parameter DEV_MEM = 4'h0, DEV_ONCHIP=4'h1, DEV_IO=4'h2;

    logic [3:0] device, secondary_device;
    assign device = DataAddr[15:12];
    assign secondary_device = DataAddr[11:8];//some devices have a secondary device, like DEV_IO has all the different IO units
    

    /*Memory Controller*///data_bus.sv
    logic [15:0] MemOut;
    inst_mem DataMem (DataAddr[11:0], Clock, BusIn, WriteData & (device==DEV_MEM), MemOut);
    logic mem_done, read_done;
    always_ff@(posedge Clock) begin
        if (Reset)
            read_done <= 0;//not done
        else if (device==DEV_MEM && ReadData) begin
            read_done <= ~read_done;//on the clock edge it becomes done
        end
        else begin
            read_done <= 0;//if not attempting to write then not done
        end
    end
    assign mem_done = WriteData || read_done; //write is actually only one cycle, no need to wait

    /*Controllers for HEX/SW/LEDR/KEY/IR/PS2*/
    parameter S_DEV_HEX=4'h0, S_DEV_SW=4'h1, S_DEV_LEDR=4'h2, S_DEV_KEY=4'h3, S_DEV_IR=4'h4, S_DEV_PS2=4'h5;
    logic [6:0] hex_reg[6];
    logic [9:0] ledr_reg;
    logic [15:0] out_io;
    logic done_io;
    
    logic [15:0] ps2_out;
    logic ps2_done;
    avalon_ps2 ps2_cont(Clock, Reset, DataAddr[3:0], ReadData & (device==DEV_IO && secondary_device==S_DEV_PS2), WriteData & (device==DEV_IO && secondary_device==S_DEV_PS2), BusIn, ps2_out, ps2_done, PS2_CLK, PS2_DATA);

 
    always_ff@(posedge Clock, posedge Reset) begin
        if (Reset) begin
            for (integer i = 0; i < 6; i++)
                hex_reg[i] <= 0;
                ledr_reg <= 0;
        end
        else if (device == DEV_IO) begin
            if (secondary_device==S_DEV_HEX && DataAddr[2:0] < 6) begin
                hex_reg[DataAddr[2:0]] <= BusIn[7:0];
            end
            else if (secondary_device==S_DEV_LEDR) begin
                ledr_reg <= BusIn[9:0];
            end
            /*
            else if (secondary_device==S_DEV_IR) begin
                IR_emit_reg <= BusIn[0];
            end
            IR_recv_reg <= IRDA_RXD;//update no matter what*/
        end
    end
    assign HEX = hex_reg;
    assign LEDR = ledr_reg;
	 //assign IRDA_TXD = IR_emit_reg;
	 always_comb begin
			case (secondary_device) 
				S_DEV_SW:begin
                done_io=1;//data is done immediately
                out_io={5'h0, SW};
            end
            S_DEV_KEY:begin
                done_io=1;//data is done immediately
                out_io={11'h0, KEY};
            end
            /*S_DEV_IR:begin
                    done_io=1;//single cycle
                    out_io={14'h0, IR_recv_reg};
            end*/
            S_DEV_HEX:begin
                done_io=1;
                out_io = 0;
                if (DataAddr[2:0] < 6) begin
                    out_io = {9'h0, hex_reg[DataAddr[2:0]]};
                end
            end
            S_DEV_PS2:begin
                out_io = ps2_out;
                done_io = ps2_done;
            end
            default:begin
                    done_io=1;
                    out_io=0;
            end
        endcase
	 end
	 
    

    /*Controllers for onchip secondary devices*/
	parameter S_DEV_FP = 4'h0, S_DEV_DCT=4'h1;
	 
    logic [15:0] FpOut, DctOut, out_onchip;    
    logic done_onchip, fp_waitreq, dct_done;
    avalon_fp_mult fp_mult(Clock, Reset, DataAddr[2:0], ReadData & (device==DEV_ONCHIP && secondary_device==S_DEV_FP), WriteData & (device == DEV_ONCHIP && secondary_device==S_DEV_FP), BusIn, FpOut, fp_waitreq);
    avalon_dct dct(Clock, Reset, DataAddr[7:0], ReadData & (device==DEV_ONCHIP && secondary_device==S_DEV_DCT), WriteData & (device == DEV_ONCHIP && secondary_device==S_DEV_DCT), BusIn, DctOut, dct_done);

    always_comb begin
        case (secondary_device)
            S_DEV_FP:begin
                out_onchip = FpOut;
                done_onchip = ~fp_waitreq;
			end
            S_DEV_DCT:begin
                out_onchip = DctOut;
                done_onchip = dct_done;
			end
            default:begin
                out_onchip = 0;
                done_onchip = 1;
            end
        endcase
    end

    /*Multiplexer for the output logic*/
    always_comb begin
        case(device)
            DEV_MEM:begin
                DataDone=mem_done; //memory is single-cycle
                BusOut=MemOut;
            end
            DEV_ONCHIP:begin
                DataDone=done_onchip;
                BusOut=out_onchip;
            end
            DEV_IO:begin
                DataDone = done_io;
                BusOut = out_io;
            end
            default:begin
            DataDone=1;
            BusOut=0;
            end
        endcase
    end

    /*always_ff@(posedge Clock) begin
        if (DataDone) begin
            if (ReadData) begin
                $display("BUS: Load [0x%x] = 0x%x", DataAddr, BusOut);
            end
            else if (WriteData) begin
                $display("BUS: Store [0x%x] = 0x%x", DataAddr, BusIn);
            end
        end
    end*/

endmodule