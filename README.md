# Project Description
This is my final project for ECE342. It has two primary components
1. Implements a fully pipelined 5-stage processor with forwarding and primitive (not-taken) branch prediction. 
2. Implement a memory-mappped verilog unit that performs the Discrete-Cosine-Transform (DCT) in hardware achieving 500,000 % improvement versus software version. 

## Repository Structure
Inside the dct_nios folder is a system with a NIOS II/f processor connected to the DCT unit. 
There are some benchmarks that demonstrate the empirical performance of the DCT unit as compared to a software implementation. 

Inside the "processor" directory is the verilog for the custom pipelined processor, which is also connected to the DCT unit

# Processor 
The processor system and quartus project can be found in the "processor" folder. 

# DCT Unit
