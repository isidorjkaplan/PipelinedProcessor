/*Defining parameters for readability*/
parameter NUM_REGS = 8;
parameter WORD_SIZE = 16;

parameter REG_BITS = $clog2(NUM_REGS);
parameter STAGE_BITS = $clog2(NUM_STAGES);
parameter OPCODE_BITS = 3;

typedef enum {Fetch=0, Decode=1, Execute=2, Memory=3, Writeback=4} Stages;
parameter NUM_STAGES = Writeback+1;
typedef enum {LR=5, SP=6, PC=7} RegNames;
//Will change this later
typedef enum {NOP, Mov, Mvt, Branch, Add, Sub, Load, Store, Logic, Cmp,  Other} Instr;
typedef enum {NO_ALU, MOV, ADD, SUB, MULT, DIV, LSL, ASL, LSR, ASR, ROR} ALU_OP;
//none = 3'b000, eq = 3'b001, ne = 3'b010, cc = 3'b011, cs = 3'b100, pl = 3'b101, mi = 3'b110, link = 3'b111
typedef enum {NONE=0, EQ=1, NE=2, CC=3, CS=4, PL=5, MI=6} Condition;

module processor (
    input [WORD_SIZE-1:0] DataIn, InstrIn, //input ports for data and instructions
    input DataDone,
    input Reset, Clock, Enable, //control signals
    output logic [WORD_SIZE-1:0] DataOut, //Output Data Port for Writes
    output logic [WORD_SIZE-1:0] DataAddr, InstrAddr, //Address ports for data and instructions
    output logic WriteData, ReadData //Instr always assumed read=1
);
    //Decode related parameters
    parameter mv = 3'b000, mvt_b = 3'b001, add = 3'b010, sub = 3'b011, ld = 3'b100, st = 3'b101, and_ = 3'b110, other = 3'b111;
    latched_values nop_value;
    assign nop_value = '{default:0, nop:1, instr:NOP, alu_op:NO_ALU, cond:NONE};

    /*Define the registers*/
    logic [WORD_SIZE-1:0] registers[NUM_REGS]; //general purpose register file
    latched_values stage_regs[NUM_STAGES];//latched values at each gate
    cpsr status_reg; //define the status register


    /*Combinational Values*/
    latched_values stage_comb_values[NUM_STAGES]; //combinational logic writes this based on state_regs
    control_signals signals; //the control values
    cpsr next_status_value;
    logic alu_cout;
    logic exec_cond_met;
    stall_types debug_stall_type;//for debugging only in modelsim

    logic stall, flush;


    /*The logic for each stage*/
    always_comb begin : stage_logic
        /*Initilization to avoid latch inference*/
        signals = '{default:0};//set all signals to zero to avoid latch
        for (integer i = 0; i < NUM_STAGES; i++)
            stage_comb_values[i] = nop_value; //if nothing else inserted, its a nop

        DataAddr = 0;
        ReadData = 0;
        WriteData = 0;
        DataOut = 0;
        stall = 0;
        flush = 0;
        debug_stall_type = '{default:0};
        next_status_value = 0;
        alu_cout = 0;
        exec_cond_met = 0;
        InstrAddr = 0;

        if (!Reset) begin
            next_status_value = status_reg; 
            /*Writeback Stage*/
            if (!stall  && !flush) begin//always true
                stage_comb_values[Writeback] = stage_regs[Memory];
                if (stage_regs[Memory].writeback) begin
                    signals.write_reg[stage_regs[Memory].rX] = 1;
                    signals.write_values[stage_regs[Memory].rX] = stage_regs[Memory].out;
                end
            end
            else
                stage_comb_values[Writeback] = stage_regs[Writeback];

            /*Memory Stages*/
            if (!stall  && !flush) begin
                stage_comb_values[Memory] = stage_regs[Execute];
                if ((stage_regs[Execute].read || stage_regs[Execute].write)) begin
                    DataAddr = stage_regs[Execute].op2;
                    ReadData = stage_regs[Execute].read;
                    WriteData = stage_regs[Execute].write;
                    if (stage_regs[Execute].write) begin
                        DataOut = stage_regs[Execute].op1;
                    end
                    /*Checking if the data is done and handling it*/
                    if (DataDone) begin
                        if (stage_regs[Execute].read) begin
                            stage_comb_values[Memory].out = DataIn;
                        end
                    end
                    else begin
                        stall = 1;
                        debug_stall_type.memory = 1;//mempory stall
                        stage_comb_values[Memory] = nop_value;
                    end
                end
            end
            else if (!flush)
                stage_comb_values[Memory] = stage_regs[Memory];

             /*Execute Stage*/
            if (!stall  && !flush) begin
                /*The Execute part of this stage*/
                stage_comb_values[Execute] = stage_regs[Decode];
                case (stage_regs[Decode].alu_op)
                    ADD:{alu_cout, stage_comb_values[Execute].out} = stage_regs[Decode].op1 + stage_regs[Decode].op2;
                    SUB:{alu_cout, stage_comb_values[Execute].out} = stage_regs[Decode].op1 - stage_regs[Decode].op2;
                    MOV:stage_comb_values[Execute].out = stage_regs[Decode].op2; //move r2 into r1
                endcase
                
                case (stage_regs[Decode].cond)
                    EQ:exec_cond_met = status_reg.zero;
                    NE:exec_cond_met = ~status_reg.zero;
                    CC:exec_cond_met = ~status_reg.carry;
                    CS:exec_cond_met = status_reg.carry;
                    PL:exec_cond_met = ~status_reg.zero & ~status_reg.negative;
                    MI:exec_cond_met = ~status_reg.zero & status_reg.negative;
                    default:exec_cond_met = 1;
                endcase

                if (!exec_cond_met) begin
                    stage_comb_values[Execute] = nop_value; //flush this instruction, condition failed
                end
                else if (exec_cond_met && stage_regs[Decode].instr == Branch) begin
                    flush = 1; //if we are branching, flush all earlier instructions
                end
                else if (stage_regs[Decode].update_flags) begin
                    next_status_value.zero = stage_comb_values[Execute].out == 0;
                    next_status_value.carry = alu_cout;
                    next_status_value.negative = signed'(stage_comb_values[Execute].out) < 0;
                    next_status_value.overflow =  stage_regs[Decode].alu_op == SUB &&
                        (stage_regs[Decode].op1[WORD_SIZE-1] != stage_comb_values[Execute].out[WORD_SIZE-1]) &&
                        (stage_regs[Decode].op1[WORD_SIZE-1] == stage_regs[Decode].op2[WORD_SIZE-1]);
                end
            end
            else if (!flush)
                stage_comb_values[Execute] = stage_regs[Execute];

            /*Decode Stage*/
            if (!stall && !flush) begin //note if it is 0 then nop
                if (stage_regs[Fetch].out != 0) begin
                    //extract the opcode bits
                    //CASE1:  III M XXX DDDDDDDDD
                    //CASE2:  III M XXX 000000 YYY
                    stage_comb_values[Decode].writeback = 1; 
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
                            //If it is immediate, or its not immediate but has the extra flags set to zero then it is a CMP
                            if (stage_comb_values[Decode].imm || (!stage_comb_values[Decode].imm && stage_regs[Fetch].out[8:3]==0)) begin
                                stage_comb_values[Decode].instr = Cmp; //it is a cmp instr
                                stage_comb_values[Decode].alu_op = SUB; //subtract two operands
                                stage_comb_values[Decode].update_flags = 1; //update flags for cmp
                                stage_comb_values[Decode].writeback = 0;
                            end
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
                        ////none = 3'b000, eq = 3'b001, ne = 3'b010, cc = 3'b011, cs = 3'b100, pl = 3'b101, mi = 3'b110, link = 3'b111
                        case (stage_comb_values[Decode].rX)
                            0:stage_comb_values[Decode].cond = NONE;
                            1:stage_comb_values[Decode].cond = EQ;
                            2:stage_comb_values[Decode].cond = NE;
                            3:stage_comb_values[Decode].cond = CC;
                            4:stage_comb_values[Decode].cond = CS;
                            5:stage_comb_values[Decode].cond = PL;
                            6:stage_comb_values[Decode].cond = MI;
                        endcase
                        //stage_comb_values[Decode].cond = $cast(Condition, stage_comb_values[Decode].rX); //previous rX field becomes cond
                        stage_comb_values[Decode].alu_op = ADD;
                        stage_comb_values[Decode].rX = PC;
                        stage_comb_values[Decode].op1 = registers[PC];
                    end
                    else if (stage_comb_values[Decode].instr == Mvt) begin
                        stage_comb_values[Decode].alu_op = MOV;
                        stage_comb_values[Decode].op2 = stage_comb_values[Decode].op2 << 8;//this comes for free, reindexing
                    end

                    //Control signals for reading and writing to memory
                    stage_comb_values[Decode].read = stage_comb_values[Decode].instr == Load;
                    stage_comb_values[Decode].write = stage_comb_values[Decode].instr == Store;
                    //Writeback for all instructions except a store
                    if (stage_comb_values[Decode].instr == Store) begin
                        stage_comb_values[Decode].writeback = 0;
                    end

                    /*Decide if we have a RAW hazard and need to stall*/
                    for (integer i = Decode; i < Writeback; i++) begin
                        if ((stage_regs[i].writeback && stage_regs[i].rX == stage_comb_values[Decode].rX)
                            || (stage_regs[i].writeback && stage_regs[i].rX == stage_comb_values[Decode].rY && !stage_comb_values[Decode].imm)
                            ) begin
                            //stall fetch
                            stall = 1;
                            //Next stage will read a NOP coming out of decode
                            stage_comb_values[Decode] = nop_value;
                            debug_stall_type.raw = 1;
                        end
                        //If a branch is in the pipeline then we stall entirely and flush the instruction in fetch
                        //We must wait until the branch writes-back a new PC value
                        //note that this is actually until the cycle AFTER it completes writeback since we look at the reg for writeback
                    end
                end           
            end
            else if (!flush)
                stage_comb_values[Decode] = stage_regs[Decode];
            if (!stall) begin
                for (integer i = Decode; i <= Writeback; i++) begin
                    if (stage_regs[i].instr == Branch) begin
                        stall = 1;
                        stage_comb_values[Decode] = nop_value;
                        debug_stall_type.control = 1;
                    end
                end
            end

            /*Fetch stage*/
            if (!stall && !flush) begin
                stage_comb_values[Fetch] = '{default:0, instr:NOP, alu_op:NO_ALU, cond:NONE}; //new empty latched values struct
                signals.write_reg[PC] = 1'b1; //we will write the new pc value
                signals.write_values[PC] = registers[PC] + 1; //by default increment one word
                InstrAddr = registers[PC] + 1;
                stage_comb_values[Fetch].out = InstrIn; //latch the instruction value
            end //else gets a nop by default
            else begin
                if (!flush)
                    stage_comb_values[Fetch] = stage_regs[Fetch];
                InstrAddr = registers[PC];
            end
            //Else it just takes a nop anyways

            /*Stall Logic*/

        end
    end

    always_ff@(posedge Clock, posedge Reset) begin
        if (Reset) begin
            for (integer i = 0; i < NUM_STAGES; i++)
                stage_regs[i] <= nop_value;
            for (integer i = 0; i < NUM_REGS; i++)
                registers[i] <= 0;
            registers[PC] <= -1;//so that +1 is =0 for first instr
            status_reg <= 0;
        end
        else begin
            status_reg <= next_status_value;
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
        //InstrAddr <= signals.InstrAddr;
        //WriteData <= signals.WriteData;
        //ReadData <= signals.ReadData;

    end

    /*The latching of the values for each stage*/

    
endmodule

typedef struct packed {
    logic raw;
    logic memory;
    logic control;
} stall_types;

typedef struct packed{
    logic negative;//N
    logic zero;//Z
    logic carry;//C
    logic overflow;//V
} cpsr;

typedef struct {
    logic write_reg [NUM_REGS]; //should we write to each register
    logic [WORD_SIZE-1:0] write_values[NUM_REGS]; //if write_reg is true, what should we write
    //logic [NUM_STAGES-1:0] stall; //if true then that stage will stall
    logic flush[NUM_STAGES];


    //logic [WORD_SIZE-1:0] DataOut; //Output Data Port for Writes
    //logic [WORD_SIZE-1:0] /*DataAddr, */InstrAddr; //Address ports for data and instructions
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
    logic update_flags;//should we update ALU flags on result

    Condition cond;

} latched_values;