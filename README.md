# Project Description
This is my final project for ECE342. It has two primary components
1. Implements a fully pipelined 5-stage processor with forwarding and primitive (not-taken) branch prediction. 
2. Implement a memory-mappped verilog unit that performs the Discrete-Cosine-Transform (DCT) in hardware achieving 500,000 % improvement versus software version. 

## Repository Structure
Inside the dct_nios folder is a system with a NIOS II/f processor connected to the DCT unit. 
There are some benchmarks that demonstrate the empirical performance of the DCT unit as compared to a software implementation. 

Inside the "processor" directory is the verilog for the custom pipelined processor, which is also connected to the DCT unit

# Processor 
The processor system and quartus project can be found in the "processor" folder. Some of the notable files are listed below
## Verilog
* [de1soc_top.sv](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/de1soc_top.sv): Implements the top-level connections, connecting the processor to the instruction memory and the data bus which contains all peripherals. 
* [processor.sv](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/processor.sv): Where all the magic happens. This is the processor itself. 
* [data_bus.sv](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/data_bus.sv): This file implements the data bus. All load and store instructions go through here and all of the various memory-mapped units are instantiated in this file, including the primary data memory. As a warning, the instruction memory is not in here as the processor has a dedicated read/addr port for the instructions which does not connect to memory-mapped units, just directly connects to instruction memory. 
* [dct.sv](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/dct.sv): As mentioned above, the DCT unit is connected to the processor rom the data_bus.sv file. This is the actual file for it. 

## Programs
This processor runs a bare-bones assembly-language provided for course labs in ECE243. I did NOT design the assembly language and do not take credit for that. This project was about designing a pipelined processor, not an assembly language. Programs can be compiled using the [sbasm.py](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/programs/sbasm.py) which was provided to me in ECE243. 

I wrote a number of programs to run on the processor, which are listed below:
* [dct_io.s](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/programs/dct_io.s) This is an interactive program which has two phases. First it takes in an 8-word array from the user interactively, and then it displays interactively the 8-word DCT of that initial array, as computed by the memory-mapped DCT unit. 
* [dct_test.s](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/programs/dct_test.s) This is a program meant to be run in model-sim only. It performs the DCT of a given array and stores the result in memory. It was primarilly used to inspect in model-sim that everything was working. 
* [test.s](https://github.com/isidorjkaplan/PipelinedProcessor/blob/main/processor/programs/test.s) This is a program containing a number of different micro-benchmarks meant to be run in model-sim to inspect the contents of various registers and ensure that it works correctly. This program was used to debug the processor itself and ensure that RAW hazards and branches were executed correctly without violating proper sequential semantics or suffering from various hazards. 


# DCT Unit
I dont even want to write this. I was forced to make the DCT unit against my will. I just wanted to submit the processor but was told this is not a processor course and had to add something extra so here it is. Let the record permanently show my objection. 

Inside the "dct_nios" folder the DCT unit is connected to a nios processor. There is a benchmark which analyzes its comparative performance against software implemented DCT's in fixed-point and in floating-point using and not using a hardware accellerated floating point unit. 
