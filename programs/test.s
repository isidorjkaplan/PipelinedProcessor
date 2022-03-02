.define STACK_TOP 0x1000
.define FP_ADDRESS 0x1000
.define HEX_ADDRESS 0x2000
.define SW_ADDRESS 0x3000
.define LEDR_ADDRESS 0x4000
.define KEY_ADDRESS 0x5000


START:
    mvt r5, #STACK_TOP //stack pointer
    //set initial values to 16. Doing this so I can later see that push and pop works restoring to this
    mv r0, #16
    mv r1, #16
    mv r2, #16
    mv r3, #16
    mv r4, #16

MAIN:
    bl COUNT_TEST
    bl NO_RAW_TEST
    b KILL

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
    //insert NOP to ensure instructions finish before KILL terminates processor
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
    //Kill processor
    mvt r0, #0xff00
    add r0, #0xff
    st r0, [r0] //this signifies to kill processor if in simulator mode
    //if not in simulator then we must spin
END: 
    b END




