# Pin Assignment for Project 2

# 1. Main System Clock (50 MHz)
set_location_assignment PIN_P11 -to clock_raw
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clock_raw

# 2. Reset and Buttons
set_location_assignment PIN_B8  -to reset
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to reset
set_location_assignment PIN_A7  -to button
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to button

# 3. Switches (SW9 for Fractal Select, SW1 for Color Pause)
set_location_assignment PIN_F15 -to fractal_select
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to fractal_select
set_location_assignment PIN_C10 -to control_select
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to control_select

# 4. VGA Sync Signals
set_location_assignment PIN_N3  -to vga_hs
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vga_hs
set_location_assignment PIN_N1  -to vga_vs
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vga_vs

# 5. VGA Red (4-bit)
set_location_assignment PIN_AA1 -to vga_r[0]
set_location_assignment PIN_V1  -to vga_r[1]
set_location_assignment PIN_Y2  -to vga_r[2]
set_location_assignment PIN_Y1  -to vga_r[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vga_r

# 6. VGA Green (4-bit)
set_location_assignment PIN_W1  -to vga_g[0]
set_location_assignment PIN_T2  -to vga_g[1]
set_location_assignment PIN_R2  -to vga_g[2]
set_location_assignment PIN_R1  -to vga_g[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vga_g

# 7. VGA Blue (4-bit)
set_location_assignment PIN_P1  -to vga_b[0]
set_location_assignment PIN_T1  -to vga_b[1]
set_location_assignment PIN_P4  -to vga_b[2]
set_location_assignment PIN_N2  -to vga_b[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vga_b

# Commit assignments
export_assignments