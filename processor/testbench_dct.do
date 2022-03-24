vlib work

vlog *.v
vlog *.sv

vsim -L altera_mf_ver testbench_dct

log *
log dut_dct/*
log dut_dct/cos_q15
log dut_dct/result
log dut_dct/dct_term_latch
log dut_dct/signal

add wave *
add wave dut_dct/*
add wave dut_dct/cos_q15
add wave dut_dct/result
add wave dut_dct/dct_term_latch
add wave dut_dct/signal

run -all