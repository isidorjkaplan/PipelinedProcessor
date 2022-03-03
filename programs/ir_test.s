//RAM RANGE
.define STACK_TOP 0x1000
//ONBOARD UNIT ADDRESSES
.define FP_ADDRESS 0x1000
//IO ADRESSES
.define HEX_ADDRESS 0x2000
.define SW_ADDRESS 0x2100
.define LEDR_ADDRESS 0x2200
.define KEY_ADDRESS 0x2300
.define IR_ADDRESS 0x2400

START:
    mvt r5, #STACK_TOP //stack pointer
    mv r1, #0 //max IR value seen
MAIN:
    mvt r4, #SW_ADDRESS
    ld r0, [r4] //get switch values
    //put SW on HEX[0] so we can see their values for debugging
    mvt r4, #HEX_ADDRESS
    st r0, [r4]

    and r0, #1 //extract lower bit
    or r1, r0

    mvt r4, #IR_ADDRESS
    st r1, [r4] //write IR_OUT = SW[0]

    ld r0, [r4] //read r0=IR_IN
    mvt r4, #LEDR_ADDRESS
    st r0, [r4] //store LEDR[0] = IR_IN
    b MAIN //repeat
