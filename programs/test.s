START:
    mv r0, #0
    mv r1, #0

//Passes test 6
TEST6:
    mv r0, #0
    mv r3, #1
    mv r4, #2
    mv r5, #3
    mv r6, #4
TEST6_LOOP:
    add r0, #1
    mv r1, #TEST6_DATA
    add r3, #2
    add r4, #3
    add r5, #4
    add r6, #5
    ld r2, [r1]
    st r0, [r1]
    cmp r0, #10
    beq TEST6
    b TEST6_LOOP

TEST6_DATA:
    .word 0x12

TEST5:
    add r0, #1
    add r1, #1
    add r0, r1 
    b TEST5



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

TEST4:
    mv r3, #TEST4_WORD
    ld r4, [r3] //should load word properly and wait until okay with stalls
    mv r0, #0
    mv r1, #0

TEST3://passes test3 cases
    add r0, #1 //(1,0)
    add r1, r0 //(1,1)
    add r0, #1 //(2,1)
    add r1, r0 //(2,3)
    add r0, #1 //(3,3)
    add r1, r0 //(3,6)
    add r0, #1 //(4,6)
    add r1, r0 //(4,10)
    b START

TEST4_WORD:
    .word 0xffff

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

