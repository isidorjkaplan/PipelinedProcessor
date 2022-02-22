vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver tb


log proc/registers
log proc/*

add wave proc/registers
add wave proc/*
run -all