library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ads;
use ads.ads_fixed.all;
use ads.ads_complex_pkg.all;

library vga;
use vga.vga_fsm;
use vga.vga_data.all;

use work.color_data.all;

use work.pipeline_pkg.all;

entity toplevel is
	generic (
		width : natural := vga_res_default.horizontal.active;
		height : natural := vga_res_default.vertical.active
	);
	port(
		clock_raw : in std_logic;
		reset : in std_logic; -- Active low
		fractal_select : in std_logic;
		control_select : in std_logic;
		button : in std_logic; -- Active low

		vga_hs   : out std_logic;
		vga_vs   : out std_logic;

		vga_r    : out std_logic_vector(3 downto 0);
		vga_g    : out std_logic_vector(3 downto 0);
		vga_b    : out std_logic_vector(3 downto 0)
	);
end entity;

architecture rtl of toplevel is
	constant ITERATIONS : natural := 16;
	constant THRESHOLD : ads_sfixed := to_ads_sfixed(4);
	constant OFFSET : ads_complex := (
			re => to_ads_sfixed(-1.5),
			im => to_ads_sfixed(-1)
		);
	constant ZOOM : ads_sfixed := to_ads_sfixed(0.5);
	constant STEP : ads_sfixed := (to_ads_sfixed(1) / ZOOM) / to_ads_sfixed(height);
	
	signal chain : pipeline_bus(0 to ITERATIONS);

	signal vga_clock : std_logic;

	signal point : coordinate := (x => 0, y => 0);
	signal point_valid : boolean;
	
	signal c_in : ads_complex := complex_zero;
	signal z_in : ads_complex := complex_zero;
	signal c_julia : ads_complex;
	
	signal end_frame : std_logic := '0';
	
	signal stage_data : natural;
	signal stage_valid : boolean := false;
	
	signal debouncer : std_logic_vector(1 downto 0);

	signal palette : palette_index_type := 0; 
	signal color : rgb_color;
begin
	pll_clock : work.clock40
		port map (
			inclk0 => clock_raw,
			c0 => vga_clock,
			locked => open
		);

	vga_driver : entity vga_fsm
		port map (
			vga_clock   => vga_clock,
			reset       => reset,
			point       => point,
			point_valid => point_valid,
			h_sync      => vga_hs,
			v_sync      => vga_vs
		);
		
	julia_anim : entity work.julia_animator
		port map (
			clock => vga_clock,
			reset => reset,
			trigger => end_frame,
			c_out => c_julia
		);
		
	process(vga_clock)
	begin
		if rising_edge(vga_clock) then
			if point.x = 0 and point.y = 0 and not (control_select = '0' and button = '0') then
				end_frame <= '1';
			else
				end_frame <= '0';
			end if;
		end if;
	end process;
		
	process(vga_clock)
	begin
		if rising_edge(vga_clock) then
			debouncer <= debouncer(0) & button;
			
			-- Upon button press
			if debouncer = "10" and control_select = '1' then
				if palette = palette_index_type'high then
					palette <= 0;
				else
					palette <= palette + 1;
				end if;
			end if;
		end if;
	end process;
		
	process(vga_clock)
	begin
		if rising_edge(vga_clock) then
			if fractal_select = '0' then
				z_in <= complex_zero;
				
				c_in.re <= c_in.re + STEP;
				
				if point.x = 0 then
					c_in.im <= c_in.im + STEP;
					c_in.re <= OFFSET.re;
				end if;
				
				if point.y = 0 then
					c_in.im <= OFFSET.im;
				end if;
				
			else
				c_in <= c_julia;
				z_in.re <= z_in.re + STEP;
								
				if point.x = 0 then
					z_in.im <= z_in.im + STEP;
					z_in.re <= OFFSET.re;
				
					if point.y = 0 then
						z_in.im <= OFFSET.im;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	chain(0) <= (
		z => z_in,
		c => c_in,
		stage_data => 0,
		stage_overflow => false,
		stage_valid => point_valid
	);

	generate_pipeline : for i in 0 to ITERATIONS - 1 generate
		stage : pipeline_stage
			generic map (
				threshold => THRESHOLD,
				stage_number => i
			)
			port map (
				reset => reset,
				clock => vga_clock,
				stage_input => chain(i),
				stage_output => chain(i+1)
			);
	end generate generate_pipeline;

	stage_data <= chain(ITERATIONS).stage_data;
	stage_valid <= chain(ITERATIONS).stage_valid;
	
	process(vga_clock)
		constant STEP : natural := ITERATIONS / (color_index_type'high + 1);
	begin
		if rising_edge(vga_clock) then
			if stage_valid then
				color <= get_color(stage_data, get_table(palette)); -- Number of colors should be number of iterations
			else
				color <= color_black; -- Must be low during blanking
			end if;
		end if;
	end process;

	vga_r <= std_logic_vector(to_unsigned(color.red, 4));
	vga_g <= std_logic_vector(to_unsigned(color.green, 4));
	vga_b <= std_logic_vector(to_unsigned(color.blue, 4));
end architecture;