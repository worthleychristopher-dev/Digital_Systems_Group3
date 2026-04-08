create_clock -name {MAX10_CLK1_50} -period 20.000 [get_ports {MAX10_CLK1_50}]
create_clock -name {ADC_CLK_10}    -period 100.000 [get_ports {ADC_CLK_10}]
derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous \
    -group [get_clocks {MAX10_CLK1_50}] \
    -group [get_clocks {ADC_CLK_10}] \
    -group [get_clocks {*pll*|clk[0]}] \
    -group [get_clocks {*pll*|clk[1]}]

# Suppress false path inside ADC primitive
set_false_path -from [get_clocks {*pll*|clk[0]}] \
               -to [get_registers {*U_ADC*|eoc*}]
					
set_false_path -to [get_ports {HEX0[*]}]
set_false_path -to [get_ports {HEX1[*]}]
set_false_path -to [get_ports {HEX2[*]}]
set_false_path -to [get_ports {HEX3[*]}]
set_false_path -to [get_ports {HEX4[*]}]
set_false_path -to [get_ports {HEX5[*]}]
set_false_path -to [get_ports {LEDR[*]}]