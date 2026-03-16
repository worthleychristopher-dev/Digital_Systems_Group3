library ieee;
use ieee.std_logic_1164.all;

library ads;
use ads.ads_fixed.all;
use ads.ads_complex_pkg.all;

package pipeline_pkg is
	type pipeline_register is record
		z : ads_complex;
		c : ads_complex;

		stage_data : natural;
		stage_overflow : boolean;

		stage_valid : boolean;
	end record pipeline_register;
	
	component pipeline_stage is
		generic (
			threshold : ads_sfixed;
			stage_number : natural
		);
		port (
			signal reset : in std_logic;
			signal clock : in std_logic;

			signal stage_input : in pipeline_register;
			signal stage_output : out pipeline_register
		);
	end component pipeline_stage;
	
	type pipeline_bus is array (natural range <>) of pipeline_register;
end package pipeline_pkg;