.define STACK_TOP 0x1000
.define FP_ADDRESS 0x1000
.define HEX_ADDRESS 0x2000
.define SW_ADDRESS 0x3000
.define LEDR_ADDRESS 0x4000
.define KEY_ADDRESS 0x5000


START:
    mvt r5, #STACK_TOP //stack pointer

LED_TEST:
    mvt r4, #LEDR_ADDRESS
    mvt r3, #SW_ADDRESS

    ld r0, [r3]
    st r0, [r4]
    mv pc, lr

//Terminate the program
KILL:
    //Kill processor
    mvt r0, #0xff00
    add r0, #0xff
    st r0, [r0] //this signifies to kill processor if in simulator mode
    //if not in simulator then we must spin
END: 
    b END