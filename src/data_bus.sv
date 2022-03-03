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
	 output wire IRDA_TXD //IR emitter wire
);  
    parameter DEV_MEM = 4'h0, DEV_ONCHIP=4'h1, DEV_IO=4'h2;

    logic [3:0] device, secondary_device;
	 assign device = DataAddr[15:12];
	 assign secondary_device = DataAddr[11:8];//some devices have a secondary device, like DEV_IO has all the different IO units
	 

    /*Memory Controller*/
    logic [15:0] MemOut;
    inst_mem DataMem (DataAddr[11:0], Clock, BusIn, WriteData & (device==DEV_MEM), MemOut);
    logic mem_done;
    always_ff@(posedge Clock) begin
        if (Reset)
            mem_done <= 0;//not done
        else if (device==DEV_MEM && (ReadData || WriteData)) begin
            mem_done <= ~mem_done;//on the clock edge it becomes done
        end
        else begin
            mem_done <= 0;//if not attempting to write then not done
        end
    end

    /*Controllers for HEX/SW/LEDR/KEY/IR*/
	 parameter S_DEV_HEX=4'h0, S_DEV_SW=4'h1, S_DEV_LEDR=4'h2, S_DEV_KEY=4'h3, S_DEV_IR=4'h4;
    logic [6:0] hex_reg[6];
    logic [9:0] ledr_reg;
	 logic IR_recv_reg; //IR reciever register
	 logic IR_emit_reg; //IR emitter register
	 logic [15:0] out_io;
	 logic done_io;
 
    always_ff@(posedge Clock, posedge Reset) begin
        if (Reset) begin
            for (integer i = 0; i < 6; i++)
                hex_reg[i] <= 0;
            ledr_reg <= 0;
				IR_recv_reg <= 0;
				IR_emit_reg <= 0;
        end
		  else if (device == DEV_IO) begin
			  if (secondary_device==S_DEV_HEX && DataAddr[2:0] < 6) begin
					hex_reg[DataAddr[2:0]] <= BusIn[7:0];
			  end
			  else if (secondary_device==S_DEV_LEDR) begin
					ledr_reg <= BusIn[9:0];
			  end
			  else if (secondary_device==S_DEV_IR) begin
					IR_emit_reg <= BusIn[0];
			  end
		  end
		  IR_recv_reg <= IRDA_RXD;//update no matter what
    end
    assign HEX = hex_reg;
    assign LEDR = ledr_reg;
	 assign IRDA_TXD = IR_emit_reg;
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
				S_DEV_IR:begin
					 done_io=1;//single cycle
					 out_io={14'h0, IR_recv_reg};
				end
				S_DEV_HEX:begin
					 done_io=1;
					 out_io = 0;
					 if (DataAddr[2:0] < 6) begin
							out_io = {9'h0, hex_reg[DataAddr[2:0]]};
					 end
				end
				default:begin
					 done_io=1;
					 out_io=0;
				end
			endcase
	 end
	 
    

    /*Controllers for onchip secondary devices*/
	 parameter S_DEV_FP = 4'h0;
	 
    logic [15:0] FpOut;    
    logic fp_waitreq;
    avalon_fp_mult fp_mult(Clock, Reset, DataAddr[2:0], ReadData & (device==DEV_ONCHIP && secondary_device==S_DEV_FP), WriteData & (device == DEV_ONCHIP && secondary_device==S_DEV_FP), BusIn, FpOut, fp_waitreq);

    /*Multiplexer for the output logic*/
    always_comb begin
        case(device)
            DEV_MEM:begin
                DataDone=mem_done; //memory is single-cycle
                BusOut=MemOut;
            end
            DEV_ONCHIP:begin
                DataDone=~fp_waitreq;
                BusOut=FpOut;
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

endmodule