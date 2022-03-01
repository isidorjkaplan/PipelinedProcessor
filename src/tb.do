vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver tb


log dut/proc/registers
log dut/proc/stage_regs
log dut/proc/stage_comb_values
log dut/data_bus/*
log dut/data_bus/fp_mult/*
log dut/*
log *

add wave dut/proc/registers
add wave dut/proc/stage_regs
add wave dut/proc/stage_comb_values
add wave dut/data_bus/*
add wave dut/*
add wave *

run -all