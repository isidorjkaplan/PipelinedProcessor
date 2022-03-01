vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver tb


log proc/registers
log proc/stage_regs
log proc/stage_comb_values
log proc/*
log data_bus/*
log data_bus/fp_mult/*

add wave proc/registers
add wave proc/stage_regs
add wave proc/stage_comb_values
add wave proc/*
add wave data_bus/fp_mult/*
add wave data_bus/*
run -all