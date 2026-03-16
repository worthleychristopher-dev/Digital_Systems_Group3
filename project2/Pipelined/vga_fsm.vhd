library ieee;
use ieee.std_logic_1164.all;

use work.vga_data.all;

entity vga_fsm is
	generic (
		vga_res:	vga_timing := vga_res_default
	);
	port (
		vga_clock:		in	std_logic;
		reset:			in	std_logic;

		point:			out coordinate;
		point_valid:	out boolean;

		h_sync:			out std_logic;
		v_sync:			out std_logic
	);
end entity vga_fsm;

architecture fsm of vga_fsm is
	signal next_point : coordinate := make_coordinate(0, 0);
begin
	process(vga_clock, reset) is
	begin
		if reset = '0' then
			next_point <= make_coordinate(0, 0);
		elsif rising_edge(vga_clock) then
			next_point <= next_coordinate(next_point, vga_res);
		end if;
	end process;
	
	point <= next_point;
	point_valid <= point_visible(next_point, vga_res);
	h_sync <= do_horizontal_sync(next_point, vga_res);
	v_sync <= do_vertical_sync(next_point, vga_res);

end architecture fsm;
