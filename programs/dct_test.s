.define STACK_TOP 0x1000

.define FP_ADDRESS 0x1000

.define DCT_ADDRESS 0x1100
.define DCT_SETQ_OFFSET 0x2
.define DCT_SETUP_OFFSET 0x0
.define DCT_WRITE_OFFSET 0x1

.define HEX_ADDRESS 0x2000
.define SW_ADDRESS 0x2100
.define LEDR_ADDRESS 0x2200
.define KEY_ADDRESS 0x2300

START:
    mvt r5, #STACK_TOP //stack pointer
    
    mv r0, #0
    mv r1, #0
    mv r2, #0
    mv r3, #0

MAIN:
    mv r0, #SIGNAL
    bl DCT
    //bl COUNT_SIZE
    //bl LOG2
    bl KILL


SIGNAL:
    .word 0x0400
    .word 0x0400
    .word 0x0400
    .word 0x0400
    .word 0x0400
    .word 0x0400
    .word 0x0400
    .word 0x0400
    .word 0x0 //NULL TERMINATED

//Works on INTEGERS. Will round if not exactly power of two
//Input: r0 = number
//Output: r0 = log2(number)
LOG2:
    push r1
    mv r1, #0
LOG2_LOOP:
    add r1, #1  //count one more power of two
    lsr r0, #1 //divide number by two
    cmp r0, #0 //check if number is zero yet
    bne LOG2_LOOP //repeat
    sub r1, #1

    mv r0, r1
    pop r1
    mv pc, lr
    
    

//r0 is pointer to null terminated array, counts size of array and returns in r0
COUNT_SIZE:
    push r1
    push r2
    push r3
    push r4
    mv r1, #0
LOOP_COUNT_SIZE:
    ld r2, [r0]
    cmp r2, #0
    beq LOOP_COUNT_SIZE_DONE
    add r1, #1
    add r0, #1
    b LOOP_COUNT_SIZE
LOOP_COUNT_SIZE_DONE:
    mv r0, r1
    pop r4
    pop r3
    pop r2
    pop r1
    mv pc, lr


//r0 points to array call DCT on
//stores result to the same array
DCT:
    push r0
    push r1
    push r2
    push r3
    push r4
    //Set Q format in DCT device
    mvt r4, #DCT_ADDRESS
    add r4, #DCT_SETQ_OFFSET
    mv r1, #5 //M value
    st r1, [r4]
    //setup the DCT u nit with signal size
    mvt r4, #DCT_ADDRESS
    add r4, #DCT_SETUP_OFFSET
    mv r3, r0 //save signal pointr
    bl COUNT_SIZE
    bl LOG2 //we want to write the power of two instead of just the nmber
    st r0, [r4]
    //start writing data to the DCT
    mvt r4, #DCT_ADDRESS
    add r4, #DCT_WRITE_OFFSET
LOOP_WRITE_DCT:
    ld r0, [r3]
    cmp r0, #0 //check if signal done
    beq LOOP_WRITE_DONE
    st r0, [r4]
    add r3, #1 //increment in signal
    b LOOP_WRITE_DCT
LOOP_WRITE_DONE:






    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr


KILL:
    //Kill processor
    mvt r0, #0xff00
    add r0, #0xff
    st r0, [r0] //this signifies to kill processor if in simulator mode
    //if not in simulator then we must spin
END: 
    b END
    
