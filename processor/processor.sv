/*Defining parameters for readability*/
parameter NUM_REGS = 8;
parameter WORD_SIZE = 16;

parameter REG_BITS = $clog2(NUM_REGS);
parameter STAGE_BITS = $clog2(NUM_STAGES);
parameter OPCODE_BITS = 3;

typedef enum {Fetch=0, Decode=1, Execute=2, Memory=3, Writeback=4} Stages;
parameter NUM_STAGES = Writeback+1;
typedef enum {SP=5, LR=6, PC=7} RegNames;
//Will change this later
typedef enum {NOP, Mov, Mvt, Branch, Add, Sub, Load, Store, And, Cmp, Lsl, Lsr, Asr, Ror, Or, Not, Eor, Bic, Other} Instr;
typedef enum {NO_ALU, MOV, ADD, SUB, AND, OR, NOT, EOR, MULT, DIV, LSL, ASL, LSR, ASR, ROR, BIC} ALU_OP;
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
    logic [WORD_SIZE-1:0] immediate;
    logic exec_cond_met;
    stall_types debug_stall_type;//for debugging only in modelsim
    logic [WORD_SIZE-1:0] read_registers[NUM_REGS]; //general purpose register file
    logic [NUM_REGS-1:0] read_registers_valid;

    logic stall, flush;

    //Entirely for debugging information to print the CPI
    longint num_instr;
    longint num_cycles;


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
        immediate = 0;
        read_registers_valid = -1;//all ones
        for (integer i = 0; i < NUM_REGS; i++) begin
            read_registers[i] = registers[i];
        end

        if (!Reset) begin
            next_status_value = status_reg; 
            /*Writeback Stage*/
            if (!stall  && !flush) begin//always true
                stage_comb_values[Writeback] = stage_regs[Memory];
                if (stage_regs[Memory].writeback) begin
                    signals.write_reg[stage_regs[Memory].rX] = 1;
                    signals.write_values[stage_regs[Memory].rX] = stage_regs[Memory].out;
                end
                if (stage_regs[Memory].link) begin
                    signals.write_reg[LR] = 1; //write link register
                    signals.write_values[LR] = stage_regs[Memory].next_pc;
                end
                if (stage_regs[Memory].sp_incr) begin
                    signals.write_reg[SP] = 1;
                    signals.write_values[SP] = registers[SP] + 1;
                end
                else if (stage_regs[Memory].sp_decr) begin
                    signals.write_reg[SP] = 1;
                    signals.write_values[SP] = registers[SP] - 1;
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
                            stage_comb_values[Memory].out_ready = 1;
                        end
                    end
                    else begin
                        stall = 1;
                        debug_stall_type.memory = 1;//mempory stall
                        stage_comb_values[Memory] = nop_value;
                    end
                end
            end
            else if (!flush) //i am stalling
                stage_comb_values[Memory] = stage_regs[Memory];

             /*Execute Stage*/
            if (!stall  && !flush) begin
                /*The Execute part of this stage*/
                stage_comb_values[Execute] = stage_regs[Decode];
                case (stage_regs[Decode].alu_op)
                    ADD:{alu_cout, stage_comb_values[Execute].out} = stage_regs[Decode].op1 + stage_regs[Decode].op2;
                    SUB:{alu_cout, stage_comb_values[Execute].out} = stage_regs[Decode].op1 - stage_regs[Decode].op2;
                    MOV:stage_comb_values[Execute].out = stage_regs[Decode].op2; //move r2 into r1
                    AND:stage_comb_values[Execute].out = stage_regs[Decode].op1 & stage_regs[Decode].op2;
                    OR:stage_comb_values[Execute].out = stage_regs[Decode].op1 | stage_regs[Decode].op2;
                    NOT:stage_comb_values[Execute].out = ~stage_regs[Decode].op2;
                    EOR:stage_comb_values[Execute].out = stage_regs[Decode].op1 ^ stage_regs[Decode].op2;
                    LSL:stage_comb_values[Execute].out = stage_regs[Decode].op1 << stage_regs[Decode].op2;
                    LSR:stage_comb_values[Execute].out = stage_regs[Decode].op1 >> stage_regs[Decode].op2;
                    ASR:stage_comb_values[Execute].out = stage_regs[Decode].op1 >>> stage_regs[Decode].op2;
                    //ROR:stage_comb_values[Execute].out = stage_regs[Decode].op1 <<>> stage_regs[Decode].op2;
                    BIC:stage_comb_values[Execute].out = stage_regs[Decode].op1 & ~stage_regs[Decode].op2;
                endcase
                if (!stage_comb_values[Execute].read && !stage_comb_values[Execute].write)
                    stage_comb_values[Execute].out_ready = 1;//output is ready, wont be modified further
                
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
                else if (exec_cond_met && stage_regs[Decode].modifies_reg[PC]) begin
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

            /*Forwarding logic*/
            for (integer i = Writeback; i > Decode; i--) begin
                read_registers_valid = read_registers_valid & ~stage_comb_values[i].modifies_reg; 
                if (stage_comb_values[i].out_ready && stage_comb_values[i].writeback) begin
                    read_registers_valid[stage_comb_values[i].rX] = 1;//can forward it
                    read_registers[stage_comb_values[i].rX] = stage_comb_values[i].out;
                end
                    
                /*for (integer r = 0; i < NUM_REGS; r++) begin
                    if (stage_regs[i].modifies_reg[r]) begin
                        //if rX is output reg and its ready then we can forward it
                        read_registers_valid[i] = stage_regs[i].out_ready && stage_regs[i].rX == r;
                        read_registers[i] = stage_regs[i].out;
                    end
                end*/
            end

            /*Decode Stage*/
            if (!stall && !flush) begin //note if it is 0 then nop
                if (stage_regs[Fetch].out != 0) begin
                    //extract the opcode bits
                    //CASE1:  III M XXX DDDDDDDDD
                    //CASE2:  III M XXX 000000 YYY
                    stage_comb_values[Decode].writeback = 1; 
                    stage_comb_values[Decode].opcode = stage_regs[Fetch].out[WORD_SIZE-1:WORD_SIZE-OPCODE_BITS];

                    stage_comb_values[Decode].rX = stage_regs[Fetch].out[WORD_SIZE-OPCODE_BITS-2:WORD_SIZE-OPCODE_BITS-4];
                    stage_comb_values[Decode].op1 = read_registers[stage_comb_values[Decode].rX];

                    stage_comb_values[Decode].imm = stage_regs[Fetch].out[WORD_SIZE-OPCODE_BITS-1];
                    immediate = signed'(stage_regs[Fetch].out[WORD_SIZE-OPCODE_BITS-REG_BITS-2:0]);
                    stage_comb_values[Decode].rY = stage_regs[Fetch].out[REG_BITS-1:0]; //not always used

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
                            stage_comb_values[Decode].read = 1;
                            if (stage_comb_values[Decode].imm && stage_comb_values[Decode].rY == SP) begin
                                stage_comb_values[Decode].sp_incr = 1;//increment stackpointer
                                stage_comb_values[Decode].imm = 0;//not actually immediate, just for encoding
                                stage_comb_values[Decode].modifies_reg[SP] = 1;
                                stage_comb_values[Decode].reads_reg[SP] = 1;
                            end
                        end
                        st:begin
                            stage_comb_values[Decode].instr = Store;
                            stage_comb_values[Decode].write = 1;
                            if (stage_comb_values[Decode].imm && stage_comb_values[Decode].rY == SP) begin
                                stage_comb_values[Decode].sp_decr = 1;//increment stackpointer
                                stage_comb_values[Decode].imm = 0;//not actually immediate, just for encoding
                                stage_comb_values[Decode].modifies_reg[SP] = 1;
                                stage_comb_values[Decode].reads_reg[SP] = 1;
                            end
                        end
                        and_:begin
                            stage_comb_values[Decode].instr = And;//todo
                            stage_comb_values[Decode].alu_op = AND;
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
                            else begin
                                stage_comb_values[Decode].imm = stage_regs[Fetch].out[7];
            
                                if (!stage_regs[Fetch].out[4]) begin
                                    immediate = stage_regs[Fetch].out[3:0];//trunicated immediate for other
                                    if (stage_regs[Fetch].out[6:5] == 6'b00) begin
                                        stage_comb_values[Decode].instr = Lsl;//todo
                                        stage_comb_values[Decode].alu_op = LSL;
                                    end
                                    else if (stage_regs[Fetch].out[6:5] == 6'b01) begin
                                        stage_comb_values[Decode].instr = Lsr;//todo
                                        stage_comb_values[Decode].alu_op = LSR;
                                    end
                                    else if (stage_regs[Fetch].out[6:5] == 6'b10) begin
                                        stage_comb_values[Decode].instr = Asr;//todo
                                        stage_comb_values[Decode].alu_op = ASR;
                                    end
                                    else if (stage_regs[Fetch].out[6:5] == 6'b11) begin
                                        stage_comb_values[Decode].instr = Ror;//todo
                                        stage_comb_values[Decode].alu_op = ROR;
                                    end
                                end
                                else begin
                                    immediate = 1<<stage_regs[Fetch].out[3:0];//trunicated immediate for other
                                    if (stage_regs[Fetch].out[6:5] == 6'b00) begin
                                        stage_comb_values[Decode].instr = Or;//todo
                                        stage_comb_values[Decode].alu_op = OR;
                                    end
                                    else if (stage_regs[Fetch].out[6:5] == 6'b01) begin
                                        stage_comb_values[Decode].instr = Eor;//todo
                                        stage_comb_values[Decode].alu_op = EOR;
                                    end
                                    else if (stage_regs[Fetch].out[6:5] == 6'b10) begin
                                        stage_comb_values[Decode].instr = Bic;//todo
                                        stage_comb_values[Decode].alu_op = BIC;
                                    end
                                    else if (stage_regs[Fetch].out[6:5] == 6'b11) begin
                                        stage_comb_values[Decode].instr = Not;//todo
                                        stage_comb_values[Decode].alu_op = NOT;
                                    end 
                                end
                            end
                            if (stage_comb_values[Decode].instr == Other) begin
                                $display("UNIMPL: %b", stage_regs[Fetch].out[8:3]);
                                $stop();
                            end
                        end
                    endcase

                    if (stage_comb_values[Decode].imm)
                        //use rest of bits as the operand bits
                        stage_comb_values[Decode].op2 = immediate;
                    else if (stage_comb_values[Decode].sp_decr) begin //this is a pre decrement
                        stage_comb_values[Decode].op2 = read_registers[SP] - 1; //load from the predecremented address
                    end
                    else begin
                        //decode which registers to grab op2 from and then fetch from that into op2
                        stage_comb_values[Decode].op2 = read_registers[stage_comb_values[Decode].rY];
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
                            7:stage_comb_values[Decode].link = 1;//not conditional, instead branch and link
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
          
                    //Writeback for all instructions except a store
                    if (stage_comb_values[Decode].instr == Store) begin
                        stage_comb_values[Decode].writeback = 0;
                    end

                    //if we writeback we modify the output value
                    if (stage_comb_values[Decode].writeback) begin
                        stage_comb_values[Decode].modifies_reg[stage_comb_values[Decode].rX] = 1;
                    end
                    if (stage_comb_values[Decode].link) begin//if it is a branch and link we modify the link register
                        stage_comb_values[Decode].modifies_reg[LR] = 1;
                    end
            
                    //The PC of the next instruction to execute. Used for LR
                    stage_comb_values[Decode].next_pc = registers[PC];

                    stage_comb_values[Decode].reads_reg[stage_comb_values[Decode].rX] = 1;
                    if (!stage_comb_values[Decode].imm)
                        stage_comb_values[Decode].reads_reg[stage_comb_values[Decode].rY] = 1;

                    /*Decide if we have a RAW hazard and need to stall
                    for (integer i = Decode; i < Writeback; i++) begin
                        //if a future stage modifies a register that is currently being consumed then stall
                        if ((stage_regs[i].modifies_reg & stage_comb_values[Decode].reads_reg) != 0) begin
                            //stall fetch
                            stall = 1;
                            //Next stage will read a NOP coming out of decode
                            stage_comb_values[Decode] = nop_value;
                            debug_stall_type.raw = 1;
                        end
                        //If a branch is in the pipeline then we stall entirely and flush the instruction in fetch
                        //We must wait until the branch writes-back a new PC value
                        //note that this is actually until the cycle AFTER it completes writeback since we look at the reg for writeback
                    end*/
                    if (((~read_registers_valid) & stage_comb_values[Decode].reads_reg) != 0) begin
                            stall = 1;
                            stage_comb_values[Decode] = nop_value;
                            debug_stall_type.raw = 1;
                    end
                end           
            end
            else if (!flush)
                stage_comb_values[Decode] = stage_regs[Decode];
            
            /*Check if an instruction in the pipeline modifies PC, if so stop fetching*/
            if (!stall) begin
                for (integer i = Execute; i <= Writeback; i++) begin
                    if (stage_regs[i].modifies_reg[PC]) begin
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
            num_cycles <= 0;
            num_instr <= 0;
        end
        else begin
            //keep track of number of cycles and number of instructions for debugging
            num_cycles <= num_cycles+1;//debugging only
            num_instr <= num_instr + (!stall && !flush); //debugging only, keep track if it was a useful cycle

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
    logic flush[NUM_STAGES];
} control_signals;

/*This struct is setup during the decode stage*/
typedef struct {
    logic [WORD_SIZE-1:0] op1, op2; //the explicit values of the operands (could get overwridden by forwarding)

    logic [WORD_SIZE-1:0] out; //final result, as well as temporary information in intermediate levels
    logic out_ready; //is the output ready (even if not yet written back)
    
    logic [OPCODE_BITS-1:0] rX, rY; //the registers sourcing x and y (if applicable)

    logic imm; //was this immediate data or not

    logic writeback; //if true then we will writeback result into rX
    
    logic [WORD_SIZE-1:0] address; //if it interacts with memory, what address
    
    logic read, write; //should we read and write during the memory stages

    logic nop; //true/false value if it is a nop, if so all other stuff get ignored
    
    logic [NUM_REGS-1:0] modifies_reg; //a bitwise mask for if this instruction modifies a reg
    logic [NUM_REGS-1:0] reads_reg; //used for deciding if there is a RAW hazard

    logic [WORD_SIZE-1:0] next_pc;//the PC of this instruction. For debugging and also for link register

    logic link;//if true then we link the next PC into LR
    logic sp_incr, sp_decr; //increment and decrement the stack pointer

    logic [OPCODE_BITS-1:0] opcode;//not used after decode
    Instr instr; 

    ALU_OP alu_op;
    logic update_flags;//should we update ALU flags on result

    Condition cond;

} latched_values;