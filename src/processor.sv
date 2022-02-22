module processor (
    input [WORD_SIZE-1:0] DataIn, InstIn //input ports for data and instructions
    input DataWaitreq,
    input Reset, Clock, Enable, //control signals
    output [WORD_SIZE-1:0] DataOut, //Output Data Port for Writes
    output [WORD_SIZE-1:0] DataAddr, InstAddr //Address ports for data and instructions
    output WriteData, ReadData //Instr always assumed read=1
);
    /*Defining parameters for readability*/
    parameter MUM_REGS = 8;
    parameter NUM_STAGES = 5;
    parameter WORD_SIZE = 16;
    
    parameter REG_BITS = $clog2(NUM_REGS);
    parameter STAGE_BITS = $clog2(NUM_STAGES);
    parameter OPCODE_BITS = 3;

    enum {Fetch=0, Decode=1, Execute=2, Memory=3, Writeback=4} Stages;
    enum {LR=5, SP=6, PC=7} RegNames;

    /*Define the registers*/
    logic [WORD_SIZE-1:0] registers[NUM_REGS]; //general purpose register file
    latched_values stage_regs[NUM_STAGES];//latched values at each gate

    /*Combinational Values*/
    latched_value stage_comb_values[NUM_STAGES-1]; //combinational logic writes this based on state_regs
    control_signals signals; //the control values

    /*The logic for each stage*/
    always_comb begin : stage_logic
        /*Initilization to avoid latch inference*/
        signals = '{default:0};//set all signals to zero to avoid latch
        stage_comb_values = '{default:0, nop:1}; //if nothing else inserted, its a nop

        /*Fetch stage*/
        if (!signals.stall[Fetch]) begin
            stage_comb_values[Fetch] = '{default:0}; //new empty latched values struct
            signals.write_reg[PC] = 1'b1; //we will write the new pc value
            signals.write_values[PC] = registers[PC] + 1; //by default increment one word
            signals.stage_comb_values[Fetch].out = InstIn; //latch the instruction value
        end //else gets a nop by default

        /*Decode Stage*/

        /*Execute Stage*/

        /*Memory Stage*/

        /*Writeback Stage*/

        /*Stall Logic*/

        /*Flush logic*/
        generate
            for (genvar i = 0; i < NUM_STAGES; i++) begin
                if (signals.flush[i])
                    stage_comb_values[i] <= '{default:0, nop:1};
            end
        endgenerate
    end

    always_ff@(posedge Clock) begin
        /*On the clock write all the combinational output values to the state regs*/
        stage_regs <= stage_comb_values;

        /*Writeback values to their registers*/
        if (stage_regs[Writeback].writeback) //if the instr currently in writeback wants to writeback
            registers[stage_regs[Writeback].rX] <= stage_regs[Writeback].out;//write output to regfile
    end

    /*The latching of the values for each stage*/

    
endmodule

typedef struct packed {
    logic write_reg[NUM_REGS]; //should we write to each register
    logic [WORD_SIZE-1:0] write_values[NUM_REGS]; //if write_reg is true, what should we write
    logic [NUM_STAGES-1:0] stall; //if true then that stage will stall
    logic flush[NUM_STAGES];
} control_signals;

/*This struct is setup during the decode stage*/
typedef struct packed {
    logic [WORD_SIZE-1:0] op1, op2; //the explicit values of the operands (could get overwridden by forwarding)

    logic [WORD_SIZE-1:0] out; //final result, as well as temporary information in intermediate levels
    
    logic [OPCODE_BITS-1:0] rX, rY; //the registers sourcing x and y (if applicable)

    logic imm; //was this immediate data or not

    logic writeback; //if true then we will writeback result into rX
    
    logic [WORD_SIZE-1:0] address, //if it interacts with memory, what address
    
    logic read, write; //should we read and write during the memory stages

    logic nop; //true/false value if it is a nop, if so all other stuff get ignored

    logic [OPCODE_BITS-1:0] opcode; //the instruction opcode

    control_signals signals; //decoded control signals for all future levels
} latched_values;