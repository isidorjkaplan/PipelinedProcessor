/*Defining parameters for readability*/
parameter NUM_REGS = 8;
parameter NUM_STAGES = 5;
parameter WORD_SIZE = 16;

parameter REG_BITS = $clog2(NUM_REGS);
parameter STAGE_BITS = $clog2(NUM_STAGES);
parameter OPCODE_BITS = 3;

typedef enum {Fetch=0, Decode=1, Execute=2, Memory=3, Writeback=4} Stages;
typedef enum {LR=5, SP=6, PC=7} RegNames;
//Will change this later
typedef enum {Mov, Mvt, Branch, Add, Sub, Load, Store, Logic, Other} Instr;
typedef enum {NO_ALU, ADD, SUB, MULT, DIV, LSL, ASL, LSR, ASR, ROR} ALU_OP;

module processor (
    input [WORD_SIZE-1:0] DataIn, InstrIn, //input ports for data and instructions
    input DataWaitreq,
    input Reset, Clock, Enable, //control signals
    output logic [WORD_SIZE-1:0] DataOut, //Output Data Port for Writes
    output logic [WORD_SIZE-1:0] DataAddr, InstrAddr, //Address ports for data and instructions
    output logic WriteData, ReadData //Instr always assumed read=1
);


    parameter mv = 3'b000, mvt_b = 3'b001, add = 3'b010, sub = 3'b011, ld = 3'b100, st = 3'b101, and_ = 3'b110, other = 3'b111;

    /*Define the registers*/
    logic [WORD_SIZE-1:0] registers[NUM_REGS]; //general purpose register file
    latched_values stage_regs[NUM_STAGES];//latched values at each gate

    /*Combinational Values*/
    latched_values stage_comb_values[NUM_STAGES-1]; //combinational logic writes this based on state_regs
    control_signals signals; //the control values

    /*The logic for each stage*/
    always_comb begin : stage_logic
        /*Initilization to avoid latch inference*/
        signals = '{default:0};//set all signals to zero to avoid latch
        stage_comb_values = '{default:0, nop:1}; //if nothing else inserted, its a nop
        ReadData = 0;
        WriteData = 0;
        DataOut = 0;

        /*Fetch stage*/
        if (signals.stall <= Fetch) begin
            stage_comb_values[Fetch] = '{default:0}; //new empty latched values struct
            signals.write_reg[PC] = 1'b1; //we will write the new pc value
            signals.write_values[PC] = registers[PC] + 1; //by default increment one word
            signals.stage_comb_values[Fetch].out = InstrIn; //latch the instruction value
            InstrAddr = registers[PC]; //show the PC, that is what we want to get on the next cycle. 
        end //else gets a nop by default
        else
            stage_comb_values[Fetch] = '{default:0, nop:1};

        /*Decode Stage*/
        if (signals.stall <= Decode && stage_regs[Fetch].out != 0) begin //note if it is 0 then nop
            //extract the opcode bits
            //CASE1:  III M XXX DDDDDDDDD
            //CASE2:  III M XXX 000000 YYY
            stage_comb_values[Decode].opcode = stage_regs[Fetch].out[NBITS-1:NBITS-OPCODE_BITS];

            stage_comb_values[Decode].rX = stage_regs[Fetch].out[REG_BITS-1:0];
            stage_comb_values[Decode].op1 = registers[stage_comb_values[Decode].rX];

            stage_comb_values[Decode].imm = stage_regs[Fetch].out[NBITS-OPCODE_BITS-1];


            case (stage_comb_values[Decode].opcode)
                mv:stage_comb_values[Decode].instr = Mov;
                mvt_b: begin
                    if (stage_comb_values[Decode].Imm)
                        stage_comb_values[Decode].instr = Mvt;
                    else
                        stage_comb_values[Decode].instr = Branch;
                    stage_comb_values[Decode].imm = 1; //the instruction uses immediate either way
                end
                add:begin
                    stage_comb_values[Decode].instr = Add;
                    stage_comb_values[Decode].alu_op = ADD;
                end
                sub:begin 
                    stage_comb_values[Decode].instr = Sub;
                    stage_comb_values[Decode].alu_op = SUB;
                end
                ld:begin
                    stage_comb_values[Decode].instr = Load;
                end
                st:begin
                    stage_comb_values[Decode].instr = Store;
                end
                and_:begin
                    stage_comb_values[Decode].instr = Logic;//todo
                end
                other:begin
                    stage_comb_values[Decode].instr = Other;//todo
                end
            endcase

            if (stage_comb_values[Decode].imm)
                //use rest of bits as the operand bits
                stage_comb_values[Decode].op2 = stage_regs[Fetch].out[NBITS-OPCODE_BITS-REG_BITS-1:0];
            else begin
                //decode which registers to grab op2 from and then fetch from that into op2
                stage_comb_values[Decode].rY = stage_regs[Fetch].out[REG_BITS-1:0];
                stage_comb_values[Decode].op2 = registers[stage_comb_values[Decode].rY];
            end
            //Control signals for reading and writing to memory
            stage_comb_values[Decode].read = stage_comb_values[Decode].instr == Load;
            stage_comb_values[Decode].write = stage_comb_values[Decode].instr == Store;
            //Writeback for all instructions except a store
            stage_comb_values[Decode].writeback = stage_comb_values[Decode].instr != Store;            
        end
        else
            stage_comb_values[Decode] = '{default:0, nop:1};

        /*Execute Stage*/
        if (signals.stall >= Execute) begin
            /*The Execute part of this stage*/
            case (stage_regs[Decode].alu_op)
                ADD:stage_comb_values[Execute].out = stage_regs[Decode].op1 + stage_regs[Decode].op2;
                SUB:stage_comb_values[Execute].out = stage_regs[Decode].op1 - stage_regs[Decode].op2;
            endcase
        end
        else
            stage_comb_values[Execute] = '{default:0, nop:1};

        /*Memory Stage*/
        if (signals.stall >= Memory && (stage_regs[Execute].read || stage_regs[Execute].write)) begin
            //LDR OP1, [OP2]
            DataAddr = stage_regs[Execute].op2;
            ReadData = stage_regs[Execute].read;
            WriteData = stage_regs[Execute].write;
            if (stage_regs[Execute].read) begin
                ReadData = 1;
                stage_comb_values[Execute].out = DataIn;
            end
            else if (stage_regs[Execute].write) begin
                WriteData = 1;
                DataOut = stage_regs[Execute].op1;
            end
            if (DataWaitreq)
                signals.stall = Memory; //stall all earlier stages, we need to wait
        end
        else
            stage_comb_values[Memory] = '{default:0, nop:1};

        /*Writeback Stage*/
        if (signals.stall >= Writeback) begin//always true
            if (stage_regs[Memory].writeback) begin
                signals.write_reg[stage_regs[Memory].rX] = 1;
                signals.write_values[stage_regs[Memory].rX] = stage_regs[Memory].out;
            end
        end
        else
            stage_comb_values[Writeback] = '{default:0, nop:1};

        /*Stall Logic*/
        
    end

    always_ff@(posedge Clock) begin
        if (Reset) begin
            stage_regs <= 0;
            registers <= 0;
        end
        else begin
            /*On the clock write all the combinational output values to the state regs*/
            stage_regs <= stage_comb_values;

            /*Writeback values to their registers*/
            for (integer i = 0; i < NUM_REGS; i++) begin
                if (signals.write_reg[i])
                    registers[i] <= signals.write_values[i];
            end

        end
    end

    /*The latching of the values for each stage*/

    
endmodule

typedef struct {
    logic write_reg [NUM_REGS]; //should we write to each register
    logic [WORD_SIZE-1:0] write_values[NUM_REGS]; //if write_reg is true, what should we write
    logic [NUM_STAGES-1:0] stall; //if true then that stage will stall
    logic flush[NUM_STAGES];
} control_signals;

/*This struct is setup during the decode stage*/
typedef struct {
    logic [WORD_SIZE-1:0] op1, op2; //the explicit values of the operands (could get overwridden by forwarding)

    logic [WORD_SIZE-1:0] out; //final result, as well as temporary information in intermediate levels

    
    logic [OPCODE_BITS-1:0] rX, rY; //the registers sourcing x and y (if applicable)

    logic imm; //was this immediate data or not

    logic writeback; //if true then we will writeback result into rX
    
    logic [WORD_SIZE-1:0] address; //if it interacts with memory, what address
    
    logic read, write; //should we read and write during the memory stages

    logic nop; //true/false value if it is a nop, if so all other stuff get ignored

    logic [OPCODE_BITS-1:0] opcode;
    Instr isntr;

    ALU_OP alu_op;
} latched_values;