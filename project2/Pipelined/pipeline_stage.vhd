library ieee;
use ieee.std_logic_1164.all;

library ads;
use ads.ads_complex_pkg.all;
use ads.ads_fixed.all;

use work.pipeline_pkg.all;

entity pipeline_stage is
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
end entity pipeline_stage;

architecture rtl of pipeline_stage is
	-- s1 register
	signal z_re_sq : ads_sfixed;
	signal z_im_sq : ads_sfixed;
	signal z_re_im : ads_sfixed;
	
	signal c_in1 : ads_complex;
	signal stage_data1 : natural;
	signal stage_overflow1 : boolean;
	signal stage_valid1 : boolean;
	
	-- s2 register
	signal z_out_re : ads_sfixed;
	signal z_out_im : ads_sfixed;
	signal z_mag : ads_sfixed;
	
	signal c_in2 : ads_complex;
	signal stage_data2 : natural;
	signal stage_overflow2 : boolean;
	signal stage_valid2 : boolean;

begin	
	
	stage_s1: process(clock) is
	begin
		if rising_edge(clock) then
			z_re_sq <= stage_input.z.re * stage_input.z.re;
			z_im_sq <= stage_input.z.im * stage_input.z.im;
			z_re_im <= stage_input.z.re * stage_input.z.im;
			
			c_in1 <= stage_input.c;
			stage_data1 <= stage_input.stage_data;
			stage_overflow1 <= stage_input.stage_overflow;
			stage_valid1 <= stage_input.stage_valid;
		end if;	
	end process stage_s1;	
	
	stage_s2: process(clock) is
	begin
		if rising_edge(clock) then
			-- z_out = z^2 + c
			z_out_re <= z_re_sq - z_im_sq + c_in1.re;
			z_out_im <= z_re_im + z_re_im + c_in1.im;
			z_mag <= z_re_sq + z_im_sq;
			
			c_in2 <= c_in1;
			stage_data2 <= stage_data1;
			stage_overflow2 <= stage_overflow1;
			stage_valid2 <= stage_valid1;
		end if;
	end process stage_s2;
	
	stage_s3: process(clock, reset) is
	begin
		if reset = '0' then
			stage_output.z <= complex_zero;
			stage_output.c <= complex_zero;
			stage_output.stage_data <= 0;
			stage_output.stage_overflow <= false;
			stage_output.stage_valid <= false;

		elsif rising_edge(clock) then
			if stage_overflow2 then
				stage_output.stage_data <= stage_data2;
            stage_output.stage_overflow <= true;
			else
				stage_output.stage_data <= stage_number;
				stage_output.stage_overflow <= z_mag > threshold;
			end if;
			
			stage_output.z <= (re => z_out_re, im => z_out_im);
			stage_output.c <= c_in2;
			stage_output.stage_valid <= stage_valid2;
		end if;
	end process stage_s3;
end architecture rtl;