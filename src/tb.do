vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver tb

log *
add wave *
run -all