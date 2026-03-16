library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ads;
use ads.ads_fixed.all;
use ads.ads_complex_pkg.all;

entity julia_animator is
	generic (
		step : ads_complex := (re => to_ads_sfixed(0.005), im => to_ads_sfixed(0.003));
		c_start : ads_complex := (re => to_ads_sfixed(-0.8), im => to_ads_sfixed(0.156));
		c_min : ads_complex := (re => to_ads_sfixed(-0.8), im => to_ads_sfixed(-0.8));
		c_max : ads_complex := (re => to_ads_sfixed(0.4), im => to_ads_sfixed(0.6))
	);
	port (
		clock : in  std_logic;
		reset : in  std_logic;
		trigger : in  std_logic;
		c_out : out ads_complex
	);
end entity;

architecture rtl of julia_animator is
	signal c : ads_complex := c_start;
	signal dir_re, dir_im : std_logic := '1';
begin
	process(clock, reset)
	begin
		if reset = '0' then
			c <= c_start;
		elsif rising_edge(clock) then
			if trigger = '1' then
				if dir_re = '1' then
					c.re <= c.re + step.re;
				else
					c.re <= c.re - step.re;
				end if;
				
				if dir_im = '1' then
					c.im <= c.im + step.im;
				else
					c.im <= c.im - step.im;
				end if;

				if c.re > c_max.re then dir_re <= '0'; end if;
				if -c.re > -c_min.re then dir_re <= '1'; end if;
				if c.im > c_max.im then dir_im <= '0'; end if;
				if -c.im > -c_min.im then dir_im <= '1'; end if;
			end if;
		end if;
	end process;

	c_out <= c;
end architecture;