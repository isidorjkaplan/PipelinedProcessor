/*Defining parameters for readability*/
parameter NUM_REGS = 8;
parameter NUM_STAGES = 5;
parameter WORD_SIZE = 16;

parameter REG_BITS = $clog2(NUM_REGS);
parameter STAGE_BITS = $clog2(NUM_STAGES);
parameter OPCODE_BITS = 3;

typedef enum {Fetch=0, Decode=1, Execute=2, MemoryStart=3, MemoryWait=4, Writeback=5} Stages;
typedef enum {LR=5, SP=6, PC=7} RegNames;
//Will change this later
typedef enum {NOP, Mov, Mvt, Branch, Add, Sub, Load, Store, Logic, Other} Instr;
typedef enum {NO_ALU, MOV, ADD, SUB, MULT, DIV, LSL, ASL, LSR, ASR, ROR} ALU_OP;

module processor (
    input [WORD_SIZE-1:0] DataIn, InstrIn, //input ports for data and instructions
    input DataDone,
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
    latched_values stage_comb_values[NUM_STAGES]; //combinational logic writes this based on state_regs
    control_signals signals; //the control values

    /*The logic for each stage*/
    always_comb begin : stage_logic
        /*Initilization to avoid latch inference*/
        signals = '{default:0};//set all signals to zero to avoid latch
        for (integer i = 0; i < NUM_STAGES; i++)
            stage_comb_values[i] = '{default:0, nop:1, instr:NOP, alu_op:NO_ALU}; //if nothing else inserted, its a nop

        DataAddr = 0;
        ReadData = 0;
        WriteData = 0;
        DataOut = 0;

        if (!Reset) begin
            for (integer i = 0; i < NUM_STAGES; i++) begin
                //by default everything is a nop unless otherwise specified
                stage_comb_values[i] = '{default:0, nop:1, instr:NOP, alu_op:NO_ALU};
            end

            /*Fetch stage*/
            if (signals.stall <= Fetch) begin
                stage_comb_values[Fetch] = '{default:0, instr:NOP, alu_op:NO_ALU}; //new empty latched values struct
                signals.write_reg[PC] = 1'b1; //we will write the new pc value
                signals.write_values[PC] = registers[PC] + 1; //by default increment one word
                stage_comb_values[Fetch].out = InstrIn; //latch the instruction value
                signals.InstrAddr = registers[PC]; //show the PC, that is what we want to get on the next cycle. 
            end //else gets a nop by default

            /*Decode Stage*/
            if (signals.stall <= Decode && stage_regs[Fetch].out != 0) begin //note if it is 0 then nop
                //extract the opcode bits
                //CASE1:  III M XXX DDDDDDDDD
                //CASE2:  III M XXX 000000 YYY
                stage_comb_values[Decode].opcode = stage_regs[Fetch].out[WORD_SIZE-1:WORD_SIZE-OPCODE_BITS];

                stage_comb_values[Decode].rX = stage_regs[Fetch].out[WORD_SIZE-OPCODE_BITS-2:WORD_SIZE-OPCODE_BITS-4];
                stage_comb_values[Decode].op1 = registers[stage_comb_values[Decode].rX];

                stage_comb_values[Decode].imm = stage_regs[Fetch].out[WORD_SIZE-OPCODE_BITS-1];

                /*Decode which instruction it is based on the opcode*/
                case (stage_comb_values[Decode].opcode)
                    mv:begin 
                        stage_comb_values[Decode].instr = Mov;
                        stage_comb_values[Decode].alu_op = MOV;
                    end
                    mvt_b: begin
                        if (stage_comb_values[Decode].imm)
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
                    stage_comb_values[Decode].op2 = signed'(stage_regs[Fetch].out[WORD_SIZE-OPCODE_BITS-REG_BITS-2:0]);
                else begin
                    //decode which registers to grab op2 from and then fetch from that into op2
                    stage_comb_values[Decode].rY = stage_regs[Fetch].out[REG_BITS-1:0];
                    stage_comb_values[Decode].op2 = registers[stage_comb_values[Decode].rY];
                end

                if (stage_comb_values[Decode].instr == Branch) begin
                    stage_comb_values[Decode].alu_op = ADD;
                    stage_comb_values[Decode].rX = PC;
                    stage_comb_values[Decode].op1 = registers[PC] - 2;
                end

                //Control signals for reading and writing to memory
                stage_comb_values[Decode].read = stage_comb_values[Decode].instr == Load;
                stage_comb_values[Decode].write = stage_comb_values[Decode].instr == Store;
                //Writeback for all instructions except a store
                stage_comb_values[Decode].writeback = stage_comb_values[Decode].instr != Store;            
            end
            else
                stage_comb_values[Decode] = '{default:0, nop:1, instr:NOP, alu_op:NO_ALU};

            /*Execute Stage*/
            if (signals.stall <= Execute) begin
                /*The Execute part of this stage*/
                stage_comb_values[Execute] = stage_regs[Decode];
                case (stage_regs[Decode].alu_op)
                    ADD:stage_comb_values[Execute].out = stage_regs[Decode].op1 + stage_regs[Decode].op2;
                    SUB:stage_comb_values[Execute].out = stage_regs[Decode].op1 - stage_regs[Decode].op2;
                    MOV:stage_comb_values[Execute].out = stage_regs[Decode].op2; //move r2 into r1
                endcase
            end

            /*Memory Stage*/
            if ((stage_regs[Execute].read || stage_regs[Execute].write)) begin
                DataAddr = stage_regs[Execute].op2;
                ReadData = stage_regs[Execute].read;
                WriteData = stage_regs[Execute].write;
                if (stage_regs[Execute].write) begin
                    DataOut = stage_regs[Execute].op1;
                end
            end
            if (signals.stall <= MemoryStart) begin
                stage_comb_values[MemoryStart] = stage_regs[Execute];
            end

            /*Memory Recieve Stage*/
            if (signals.stall <= MemoryWait) begin
                if (!DataDone) begin
                    stall = MemoryWait; //wait here until it is done
                end//note nops are getting latched to flow into the future stages here
                else begin
                    stage_comb_values[MemoryWait] = stage_regs[MemoryStart];
                    if (state_regs[MemoryStart].read) begin
                        stage_comb_values[MemoryWait].out = DataIn;
                    end
                end
            end

            /*Writeback Stage*/
            if (signals.stall <= Writeback) begin//always true
                stage_comb_values[Writeback] = stage_regs[MemoryWait];
                if (stage_regs[MemoryWait].writeback) begin
                    signals.write_reg[stage_regs[MemoryWait].rX] = 1;
                    signals.write_values[stage_regs[MemoryWait].rX] = stage_regs[MemoryWait].out;
                end
            end

            /*Stall Logic*/

        end
        
    end

    always_ff@(posedge Clock, posedge Reset) begin
        if (Reset) begin
            for (integer i = 0; i < NUM_STAGES; i++)
                stage_regs[i] <= '{default:0, nop:1, instr:NOP, alu_op:NO_ALU};
            for (integer i = 0; i < NUM_REGS; i++)
                registers[i] <= 0;
        end
        else begin
            /*On the clock write all the combinational output values to the state regs*/
            for (integer i = 0; i < NUM_STAGES; i++)
                stage_regs[i] <= stage_comb_values[i];

            /*Writeback values to their registers*/
            for (integer i = 0; i < NUM_REGS; i++) begin
                if (signals.write_reg[i])
                    registers[i] <= signals.write_values[i];
            end
        end
        //DataOut <= signals.DataOut;
        //DataAddr <= signals.DataAddr;
        InstrAddr <= signals.InstrAddr;
        //WriteData <= signals.WriteData;
        //ReadData <= signals.ReadData;

    end

    /*The latching of the values for each stage*/

    
endmodule

typedef struct {
    logic write_reg [NUM_REGS]; //should we write to each register
    logic [WORD_SIZE-1:0] write_values[NUM_REGS]; //if write_reg is true, what should we write
    logic [NUM_STAGES-1:0] stall; //if true then that stage will stall
    logic flush[NUM_STAGES];


    //logic [WORD_SIZE-1:0] DataOut; //Output Data Port for Writes
    logic [WORD_SIZE-1:0] /*DataAddr, */InstrAddr; //Address ports for data and instructions
    //logic WriteData, ReadData; //Instr always assumed read=1
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
    Instr instr;

    ALU_OP alu_op;
} latched_values;