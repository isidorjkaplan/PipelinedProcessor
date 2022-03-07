vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver testbench_dct

log *

add wave *

run -all