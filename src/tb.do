vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver tb

log *
log proc/*
add wave *
add wave proc/*
run -all