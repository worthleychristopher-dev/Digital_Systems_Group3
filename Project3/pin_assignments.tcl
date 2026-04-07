# 1. Load the necessary Quartus Project package
package require ::quartus::project

# 2. Assign Clocks (Based on DE10-Lite Manual)
set_location_assignment PIN_P11 -to MAX10_CLK1_50
set_location_assignment PIN_N5  -to ADC_CLK_10
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to MAX10_CLK1_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ADC_CLK_10

# 3. Assign LEDs (LEDR0 to LEDR9)
set led_pins { PIN_A8 PIN_A9 PIN_A10 PIN_B10 PIN_D13 PIN_C13 PIN_E14 PIN_D14 PIN_A11 PIN_B11 }
for {set i 0} {$i < 10} {incr i} {
    set_location_assignment [lindex $led_pins $i] -to "LEDR\[$i\]"
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "LEDR\[$i\]"
}

# 4. Assign Switches (SW0 to SW9)
set sw_pins { PIN_C10 PIN_C11 PIN_D12 PIN_C12 PIN_A12 PIN_B12 PIN_A13 PIN_A14 PIN_B14 PIN_F15 }
for {set i 0} {$i < 10} {incr i} {
    set_location_assignment [lindex $sw_pins $i] -to "SW\[$i\]"
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "SW\[$i\]"
}

# 5. Assign Keys (Buttons)
set_location_assignment PIN_B8 -to "KEY\[0\]"
set_location_assignment PIN_A7 -to "KEY\[1\]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "KEY\[0\]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "KEY\[1\]"

# 6. Assign Seven Segment Displays (HEX0 to HEX5)
set sseg_pins {
    { PIN_C14 PIN_E15 PIN_C15 PIN_C16 PIN_E16 PIN_D17 PIN_C17 } 
    { PIN_C18 PIN_D18 PIN_E18 PIN_B16 PIN_A17 PIN_A18 PIN_B17 }
    { PIN_B20 PIN_A20 PIN_B19 PIN_A21 PIN_B21 PIN_C22 PIN_B22 }
    { PIN_F21 PIN_E22 PIN_E21 PIN_C19 PIN_C20 PIN_D19 PIN_E17 }
    { PIN_F18 PIN_E20 PIN_E19 PIN_J18 PIN_H19 PIN_F19 PIN_F20 }
    { PIN_J20 PIN_K20 PIN_L18 PIN_N18 PIN_M20 PIN_N19 PIN_N20 }
}

for {set i 0} {$i < 6} {incr i} {
    set segments [lindex $sseg_pins $i]
    for {set j 0} {$j < 7} {incr j} {
        set_location_assignment [lindex $segments $j] -to "HEX${i}\[${j}\]"
        set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "HEX${i}\[${j}\]"
    }
}

# 7. Global Clock Force (Using the internal path found in your Fitter report)
set_instance_assignment -name GLOBAL_SIGNAL "GLOBAL CLOCK" -to "global_inst|altclkctrl_component|outclk"

# 8. Commit and Notify
export_assignments
post_message "Pin assignments and Global Clock constraints completed successfully!"