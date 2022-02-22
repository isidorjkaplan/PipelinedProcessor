START:
    //Pipelined moving r0-r4
    mv r0, #1
    mv r1, #2
    mv r2, #3
    mv r3, #4
    mv r4, #5
    //NOP
    mv r0, r0
    mv r0, r0
    //Storing calculated values to memory
    st r0,[r0]
    st r1,[r0]
    st r2,[r0]
    st r3,[r0]
    st r4,[r0] //storing 5
    
    //Pipelined adding
    add r0, r1 //=3
    add r1, r2 //=5
    add r2, r3 //=7
    add r3, r4 //=9
    add r4, #5 //=10
    
    //Testing load instruction
    ld r0, [r0] //=5
    //NOP
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0

    b START
    //NOP
    mv r0, r0
    mv r0, r0
    mv r0, r0
    mv r0, r0
