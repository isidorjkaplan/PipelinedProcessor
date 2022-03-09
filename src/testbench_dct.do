vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver testbench_dct

log *
log dut_dct/*
log dut_dct/cos_in
log dut_dct/cos_out
log dut_dct/cos_done
log dut_dct/signal

add wave *
add wave dut_dct/*
add wave dut_dct/cos_in
add wave dut_dct/cos_out
add wave dut_dct/cos_done
add wave dut_dct/signal

run -all