START:
    //Pipelined moving r0-r4
    mv r0, #0
    mov r1, #0

TEST3:
    add r0, #1 //(1,0)
    add r1, r0 //(1,1)
    add r0, #1 //(2,1)
    add r1, r0 //(2,3)
    add r0, #1 //(3,3)
    add r1, r0 //(3,6)
    add r0, #1 //(4,6)
    add r1, r0 //(4,10)
    b TEST3


TEST2:
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    add r0, #1
    b TEST2

TEST1:
    mv r0, #LABEL
    //Move fully works
    mv r1, #2
    mv r2, #3
    mv r3, #4
    mv r4, #5

    //NOP
    mv r0, r0
    mv r0, r0
    
    //Pipelined adding
    //add r0, r1 //=3
    add r1, r2 //=5 //works
    add r2, r3 //=7 //works
    add r3, r4 //=9 //works
    add r4, #5 //=10 //works

    //NOP
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
    
    //Testing load instruction
    ld r1, [r0] //r1=0xabcd  //works
    st r3, [r0] //write 9   //works
    ld r4, [r0] //r4=9    //works

    //NOP
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0

    //Testing a store


    b START
    //NOP
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0



LABEL: 
    .word 0xabcd
