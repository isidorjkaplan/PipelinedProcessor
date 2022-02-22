module processor (
    input [WORD_SIZE-1:0] DataIn, InstIn //input ports for data and instructions
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
    parameter OPCODE_BITS = 3;

    /*Define the registers*/
    logic [WORD_SIZE-1:0] registers[NUM_REGS]; //general purpose register file
    latched_values stage_regs[NUM_STAGES];//latched values at each gate
    latched_value stage_comb_values[NUM_STAGES]; //combinational logic writes this based on state_regs

    /*The logic for each stage*/
    always_comb begin : stage_logic
        
        /*Fetch stage*/

        /*Decode Stage*/

        /*Execute Stage*/

        /*Memory Stage*/

        /*Writeback Stage*/

    end

    always_ff@(posedge Clock) begin
        /*On the clock write all the combinational output values to the state regs*/
        stage_regs <= stage_comb_values;


    end

    /*The latching of the values for each stage*/

    
endmodule

typedef struct packed {
    logic [WORD_SIZE-1:0] op1, op2; //the explicit values of the operands (could get overwridden by forwarding)

    logic [WORD_SIZE-1:0] out; //final result, as well as temporary information in intermediate levels
    
    logic [OPCODE_BITS-1:0] rX, rY; //the registers sourcing x and y (if applicable)

    logic imm; //was this immediate data or not
    
    logic [WORD_SIZE-1:0] tmp1, tmp2, tmp3; //temporary values used for 

    logic nop; //true/false value if it is a nop, if so all other stuff get ignored

    logic [OPCODE_BITS-1:0] opcode; //the instruction opcode

    control_signals signals; //decoded control signals for all future levels
} latched_values;