VGA Module Progress

This folder contains my current progress for the VGA/peripheral part of Project 2.

Files completed
- vga_data.vhd
- vga_fsm.vhd
- color_data.vhd
- toplevel.vhd

What is done
- Implemented VGA timing logic
- Implemented VGA FSM scan logic
- Fixed color package so it compiles in Quartus
- Created a top-level module connecting the VGA block
- Quartus Analysis & Synthesis compiles successfully

Current status
- VGA integration is done on the Quartus side
- Color lookup structure is prepared
- Temporary stage_data and manager_ready signals are used for testing

What is left
- Connect real manager output signals
- Final synchronization with manager module
- Hardware testing on FPGA board with VGA and monitor
