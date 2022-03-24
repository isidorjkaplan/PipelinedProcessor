.define STACK_TOP 0x1000
.define FP_ADDRESS 0x1000
.define HEX_ADDRESS 0x2000
.define SW_ADDRESS 0x2100
.define LEDR_ADDRESS 0x2200
.define KEY_ADDRESS 0x2300
.define IR_ADDRESS 0x2400
.define PS2_ADDRESS 0x2500


START:
    mvt r5, #STACK_TOP //stack pointer
    //set initial values to 16. Doing this so I can later see that push and pop works restoring to this
    mv r0, #16
    mv r1, #16
    mv r2, #16
    mv r3, #16
    mv r4, #16

MAIN:
    //bl IO_TEST
    bl PS2_TEST
    bl LOGIC_TEST
    bl COUNT_TEST
    bl NO_RAW_TEST
    bl COUNT_TEST2
    b KILL

MAX_IR_VAL:
    .word 0x0

PS2_TEST:
    push r0
    push r1
    push r2
    push r3
    push r4
    mvt r4, #PS2_ADDRESS
    mvt r3, #LEDR_ADDRESS
    ld r0, [r4]
    st r0, [r3]
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr //done, return from test


IO_TEST:
    push r0
    push r1
    push r2
    push r3
    push r4
    
    mvt r4, #SW_ADDRESS
    ld r0, [r4]

    mvt r4, #LEDR_ADDRESS
    st r0, [r4]

    mvt r4, #KEY_ADDRESS
    ld r0, [r4]

    mvt r4, #HEX_ADDRESS
    st r0, [r4]

    mvt r3, #IR_ADDRESS
    ld r0, [r3] //read the IR sesnor
    //if we have seen bigger, update r0 to 1
    //store max back into the place
    mv r3, #MAX_IR_VAL
    ld r1, [r3]
    add r0, r1
    st r0, [r3]

    add r4, #1 //move to second hex
    add r0, #2 //there should be two lit up to show that we wrote properly
    st r0, [r4] //write to the HEX1 display

    mvt r3, #SW_ADDRESS
    ld r0, [r3]
    and r0, #1
    mvt r3, #IR_ADDRESS
    st r0, [r3] //send SW[0] to IR
    add r4, #1
    st r0, [r4] //show on next hex the sam evalue as we are sending to IR

    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr //done, return from test

//A test that tests various logical instructions
LOGIC_TEST:
    push r0
    push r1
    push r2
    push r3
    push r4

    //tests for shifting, passes all
    mv r0, #1
    mv r1, #2
    lsl r0, r1 //=4
    lsl r0, r1 //=16
    lsr r0, r1 //=4
    lsr r0, r1 //=1

    //tests for logic instr, pases all
    mv r0, #0x55
    mv r1, #0xAA
    xor r0, r1 //=0xFF
    xor r0, r1 //=0x55
    or r1, r0 //=0xFF
    and r1, r0 //=0x55

    mv r0, #0
    mvn r0, r0 //=0xFF

    //tests for immediate, passes all
    mv r2, #0x1 //=1
    lsl r2, #2//=4
    lsl r2, #1//=8
    lsr r2, #3//=1
    xor r2, #1 //=0
    xor r2, #1//=1
    or r2, #2//=3
    and r2, #2//=2


    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr //done, return from test


//A subroutine that performs the count test
COUNT_TEST:
    push r0
    mv r0, #0
COUNT_LOOP:
//should have lots of stalls to avoid the RAWs
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    //while ~= 100, note jumps by 5 so hits 100
    cmp r0, #20
    bne COUNT_LOOP
    pop r0
    mv pc, lr

//A subroutine that performs the count test, no RAW stalls required
COUNT_TEST2:
    push r0
    push r1
    mv r0, #0
    mv r1, #0
COUNT_LOOP2:
    add r0, #1
    add r1, #1
    add r0, #1
    add r1, #1
    add r0, #1
    add r1, #1
    add r0, #1
    add r1, #1
    add r0, #1
    add r1, #1
    //while ~= 100, note jumps by 5 so hits 100
    cmp r0, #20
    bne COUNT_LOOP2
    pop r1
    pop r0
    mv pc, lr

//A test that avoids having raw hazards to see pipelining effect
NO_RAW_TEST:
    push r0
    push r1
    push r2
    push r3
    push r4


    mv r0, #1
    mv r1, #2
    mv r2, #3
    mv r3, #4
    mv r4, #5
    add r0, r1 //3
    add r1, r2 //5
    add r2, r3 //7
    add r3, r4 //9
    add r4, r0 //6


    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr //done, return from test


//Terminate the program
KILL:
    //Kill processor
    mvt r0, #0xff00
    add r0, #0xff
    st r0, [r0] //this signifies to kill processor if in simulator mode
    //if not in simulator then we must spin
END: 
    b START




