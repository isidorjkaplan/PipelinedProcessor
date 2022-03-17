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
    b DCT_IO_MAIN //later replace this with choose program based on keys

//CONSTANTS AND DATA

SEG7_ARRAY:  
    .word 0b00111111       // '0'
    .word 0b00000110       // '1'
    .word 0b01011011       // '2'
    .word 0b01001111       // '3'
    .word 0b01100110       // '4'
    .word 0b01101101       // '5'
    .word 0b01111101       // '6'
    .word 0b00000111       // '7'
    .word 0b01111111       // '8'
    .word 0b01100111       // '9'
    .word 0b01110111       // 'A' 1110111
    .word 0b01111100       // 'b' 1111100
    .word 0b00111001       // 'C' 0111001
    .word 0b01011110       // 'd' 1011110
    .word 0b01111001       // 'E' 1111001
    .word 0b01110001       // 'F' 1110001

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

.define KEY_READ 0
.define KEY_END_PRINT 1

DCT_IO_MAIN:
    //get length of signal in r1
    mv r0, #SIGNAL
    bl COUNT_SIZE 
    mv r1, r0
    //put signal at r0
    mv r0, #SIGNAL 
    //display we are in program section 1
    push r0
    mv r0, #1 //1 for print
    bl DISPLAY_HEX5_DIGIT 
    pop r0
    bl READ_ARRAY //read
    //display we are in program section 2
    push r0
    mv r0, #2 //1 for print
    bl DISPLAY_HEX5_DIGIT 
    pop r0
    bl PRINT_ARRAY //print
    //restart 
    b DCT_IO_MAIN //restart the branch forever

//Input: r0=ptr, r1=num elements
READ_ARRAY:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r6//lr
    mv r4, r0 //r4 = array
    mv r3, r1

READ_ARRAY_LOOP:
    
    bl GET_SW
    mv r1, #2
    bl DISPLAY_HEX_BYTE
    mv r0, r3
    mv r1, #0
    bl DISPLAY_HEX_DIGIT

    
    //logic for polling
    mv r0, #KEY_READ
    bl GET_KEY_VALUE
    cmp r0, #0
    beq READ_ARRAY_LOOP
    //wait for next key press
    mv r0, #KEY_READ
    bl POLL_RELEASE  //ensure they release
    //sample the values
    bl GET_SW
    st r0, [r4] //ARRAY[i] = SW
    //increment counter
    sub r3, #1 //decrement counter
    add r4, #1 //next position in the array
    //break condition
    cmp r3, #0
    bne READ_ARRAY_LOOP
    bl CLEAR_HEX

    pop r6 //lr
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr

//Input: r0=ptr, r1=size
PRINT_ARRAY:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r6//lr
    mv r4, r0 //r4 = &array
    mv r3, r1

PRINT_ARRAY_LOOP:
    bl GET_SW //r0 = index of array
    //make sure array in bounds
    cmp r3, r0 //check if out of bounds
    bcs PRINT_ARRAY_OUT_OF_BOUNDS
    beq PRINT_ARRAY_OUT_OF_BOUNDS
    mv r1, #2 //specify where to display index
    bl DISPLAY_HEX_BYTE //display index on HEX[3:2]
    //access the data
    add r0, r4 //r0 = &array[SW]
    ld r0, [r0] //r0 = array[SW]
    bl DISPLAY_LEDR //LEDR = array[SW]
    //display the value from the array on HEX[1:0]
    mv r1, #0
    bl DISPLAY_HEX_BYTE
    //Check if the end-print has been placed and if so terminate
PRINT_ARRAY_LOOP_END_COND:
    mv r0, #KEY_END_PRINT
    bl GET_KEY_VALUE
    cmp r0, #0
    beq PRINT_ARRAY_LOOP
    mv r0, #KEY_END_PRINT
    bl POLL_RELEASE //wait for user to release the button
    b PRINT_ARRAY_LOOP_DONE
//branches to here if out of bounds
PRINT_ARRAY_OUT_OF_BOUNDS:
    //clear LEDRs
    mv r0, #0
    bl DISPLAY_LEDR
    b PRINT_ARRAY_LOOP_END_COND
PRINT_ARRAY_LOOP_DONE:
    mv r0, #0
    bl DISPLAY_LEDR
    bl CLEAR_HEX
    //return
    pop r6 //lr
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr



//Input: r0
//Output: Nothing, value is put on LEDR
DISPLAY_LEDR:
    push r4
    mvt r4, #LEDR_ADDRESS
    st r0, [r4]
    pop r4
    mv pc, lr

//Input: r0
//Output: display r0 on HEX5
DISPLAY_HEX5_DIGIT:
    push r1
    push r6//lr
    mv r1, #5
    bl DISPLAY_HEX_DIGIT
    pop r6//lr
    pop r1
    mv pc, lr

CLEAR_HEX:
    push r0
    push r3
    push r4
    mv r3, #5
    mvt r4, #HEX_ADDRESS
    mv r0, #0
CLEAR_HEX_LOOP:
    st r0, [r4]
    sub r3, #1
    add r4, #1
    cmp r3, #0
    bne CLEAR_HEX_LOOP
    pop r4
    pop r3
    pop r0
    mv pc, lr

//Inout: r0=1 byte (2 hex digits), r1=display number
//Output: nothing
DISPLAY_HEX_BYTE:
    push r0
    push r1
    push r6//lr

    push r0
    and r0, #0xF
    bl DISPLAY_HEX_DIGIT //display lower bits
    pop r0
    lsr r0, #4 //zero out lower hex digit
    and r0, #0xF
    add r1, #1 //next hex digit
    bl DISPLAY_HEX_DIGIT

    pop r6//lr
    pop r1
    pop r0
    mv pc, lr
    

//Inout: r0=hex value, r1=display number
//Output: nothing
DISPLAY_HEX_DIGIT:
    push r0
    push r4
    push r6//lr
    mvt r4, #HEX_ADDRESS
    add r4, r1 //r4 = one we want to display on
    bl SEG7_CODE //r0 = hex code to display
    st r0, [r4]
    pop r6//lr
    pop r4
    pop r0
    mv pc, lr


//Input: nothing
//Output: r0 = SW
GET_SW:
    mvt r0, #SW_ADDRESS
    ld r0, [r0]
    mv pc, lr

//Input: r0=key number
//Output: r0= 0 or 1
GET_KEY_VALUE:
    push r1
    push r4

    mvt r4, #KEY_ADDRESS
    mv r1, #1
    lsl r1, r0 //r1 now holds the bitmask for the switch we care about
    ld r0, [r4] //get the switches
    and r0, r1 //extract bit we care about
    cmp r0, #0
    beq GET_KEY_VALUE_DONE //if it is equal to zero we are done
    mv r0, #1 //if it is not equal to zero, set it to 1
GET_KEY_VALUE_DONE:

    pop r4
    pop r1
    mv pc, lr

//Input: r0
//Output: Waits until r0 is released (0)
POLL_RELEASE:
    push r0
    push r1
    push r4

    mvt r4, #KEY_ADDRESS

    mv r1, #1
    lsl r1, r0 //r1 now holds the bitmask for the switch we care about
POLL_WAIT_NEG: //wait until it is negative
    ld r0, [r4] //get the switches
    and r0, r1 //extract bit we care about
    cmp r0, #0
    bne POLL_WAIT_NEG //it is current pressed, try again
    
    pop r4
    pop r1
    pop r0
    mv pc, lr



//Input: r0
//Output: wait until r0 is pressed
POLL_PRESS:
    push r0
    push r1
    push r4

    mvt r4, #KEY_ADDRESS

    mv r1, #1
    lsl r1, r0 //r1 now holds the bitmask for the switch we care about
POLL_WAIT_POS: //wait until it is negative
    ld r0, [r4] //get the switches
    and r0, r1 //extract bit we care about
    cmp r0, #0
    beq POLL_WAIT_POS //it is current pressed, try again
    
    pop r4
    pop r1
    pop r0
    mv pc, lr



//Input: r0 is the address of the KEY [0, 1, 2, 3]
//Output: None. Polls until the negedge (release) of SW[r0]
POLL: //verified
    push r6//lr
    bl POLL_RELEASE
    bl POLL_PRESS
    pop r6
    mv pc, lr

//Input: r0=hex digit
//Output: r0=bitcode for hex digit
SEG7_CODE:
    add r0, #SEG7_ARRAY
    ld r0, [r0]
    mv pc, lr

//Works on INTEGERS. Will round if not exactly power of two
//Input: r0 = number
//Output: r0 = log2(number)
LOG2:
    push r1
    push r6//lr
    mv r1, #0
LOG2_LOOP:
    add r1, #1  //count one more power of two
    lsr r0, #1 //divide number by two
    cmp r0, #0 //check if number is zero yet
    bne LOG2_LOOP //repeat
    sub r1, #1

    mv r0, r1
    pop r6//lr
    pop r1
    mv pc, lr
    
//r0 is pointer to null terminated array, counts size of array and returns in r0
COUNT_SIZE:
    push r1
    push r2
    push r3
    push r4
    push r6//lr
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
    pop r6 //lr
    pop r4
    pop r3
    pop r2
    pop r1
    mv pc, lr


//FILE: Code from DCT 


//r0 points to array call DCT on
//stores result to the same array
DCT:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r6 //lr
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

    mv r2, r3 //r2 = signal pointer
LOOP_WRITE_DCT:
    ld r0, [r2]
    cmp r0, #0 //check if signal done
    beq LOOP_WRITE_DONE_DCT
    st r0, [r4]
    add r2, #1 //increment in signal
    b LOOP_WRITE_DCT
LOOP_WRITE_DONE_DCT:
    mv r2, r3 //r2 = signal pointer
    mvt r4, #DCT_ADDRESS
LOOP_READ_DCT:
    //check if it is the end of the signal
    ld r0, [r2]
    cmp r0, #0
    beq LOOP_READ_DCT_DONE
    //perform the actual dct read and store back into the array
    ld r0, [r4]
    st r0, [r2] 
    add r4, #1
    add r2, #1
    b LOOP_READ_DCT
LOOP_READ_DCT_DONE:
    pop r6 //lr
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    mv pc, lr
