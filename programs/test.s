START:
    //Pipelined moving r0-r4
    mv r0, #1
    mv r1, #2
    mv r2, #3
    mv r3, #4
    mv r4, #5
    //NOP
    mv r0, #0
    mv r0, #0 
    mv r0, #0
    mv r0, #0
    mv r0, #0
    //Pipelined adding
    add r0, r1 //=3
    add r1, r2 //=5
    add r2, r3 //=7
    add r3, r4 //=9
    add r4, #5 //=10