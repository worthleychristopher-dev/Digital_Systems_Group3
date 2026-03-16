---- this file is part of the ADS library

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ads_fixed is
	-- replace here with number of bits needed for integer part
	constant msb: integer := 10;
	-- replace here with number of bits needed for fractional part
	constant lsb: integer := 22;


	-- type definition for class signed fixed
	type ads_sfixed is array(integer range msb downto -lsb) of std_logic;

	-- other constants
	-- Quartus bug?
	constant ads_zero: ads_sfixed := (others => '0');
	constant ads_minimum_value: ads_sfixed :=
				(msb => '1', others => '0');
	constant ads_maximum_value: ads_sfixed :=
				(msb => '0', others => '1');

	-- functions
	function to_ads_sfixed (
			arg:	in signed
		) return ads_sfixed;

	function to_ads_sfixed (
			arg:	in integer
		) return ads_sfixed;

	function to_ads_sfixed (
			arg:	in real
		) return ads_sfixed;

	function to_signed (
			arg: in ads_sfixed
		) return signed;

	function "+" (
			l, r:	in ads_sfixed
		) return ads_sfixed;

	function "-" (
			l, r:	in ads_sfixed
		) return ads_sfixed;

	function "-" (
			r:		in ads_sfixed
		) return ads_sfixed;

	function "*" (
			l, r:	in ads_sfixed
		) return ads_sfixed;

	function "/" (
			l, r:	in ads_sfixed
		) return ads_sfixed;

	function ">" (
			l, r:	in ads_sfixed
		) return boolean;

end package ads_fixed;

package body ads_fixed is
	constant ads_epsilon: ads_sfixed := (msb downto -lsb + 1 => '0') & "1";

	constant minimum_value: signed(ads_epsilon'length - 1 downto 0) := 
				"1" & (ads_epsilon'length - 2 downto 0 => '0');
	constant maximum_value: signed(ads_epsilon'length - 1 downto 0) :=
				"0" & (ads_epsilon'length - 2 downto 0 => '1');

	constant minimum_value_ext: signed(ads_epsilon'length downto 0) := 
				"11" & (ads_epsilon'length - 2 downto 0 => '0');
	constant maximum_value_ext: signed(ads_epsilon'length downto 0) :=
				"00" & (ads_epsilon'length - 2 downto 0 => '1');

	function unary_or (
			val: in	std_logic_vector
		) return std_logic
	is
	begin
		for i in val'range loop
			if val(i) = '1' then
				return '1';
			end if;
		end loop;
		return '0';
	end function unary_or;

	function unary_and (
			val: in std_logic_vector
		) return std_logic
	is
	begin
		for i in val'range loop
			if val(i) = '0' then
				return '0';
			end if;
		end loop;
		return '1';
	end function unary_and;

	-- take in a signed and make it into an ads_sfixed
	function to_ads_sfixed (
			arg:	in signed
		) return ads_sfixed
	is
		variable ret: ads_sfixed;
	begin
		-- safety check
		assert ret'length = arg'length
				report "argument has improper length"
					severity failure;

		for i in ret'range loop
			ret(i) := arg(i + lsb);
		end loop;
		return ret;
	end function to_ads_sfixed;

	-- take an integer and make it into an ads_sfixed
	function to_ads_sfixed (
			arg:	in integer
		) return ads_sfixed
	is
		variable ret: ads_sfixed;
		variable in_val: integer := arg;
		variable bit_value: std_logic := '0';
	begin
		if arg < 0 then
			in_val := -(arg + 1);
			bit_value := '1';
		else
			in_val := arg;
			bit_value := '0';
		end if;

		for i in ret'low to -1 loop
			ret(i) := '0';
		end loop;

		for i in 0 to ret'high loop
			if in_val mod 2 = 0 then
				ret(i) := bit_value;
			else
				ret(i) := not bit_value;
			end if;
			in_val := in_val / 2;
		end loop;

		return ret;
	end function to_ads_sfixed;

	-- take a real and make it into an ads_sfixed
	function to_ads_sfixed (
			arg: in real
		) return ads_sfixed
	is
		variable partial_result: real;
		variable ret: ads_sfixed;
	begin
		if (arg >= 2.0 ** msb) then
			report "to_ads_sfixed(real) overflow, saturating"
					severity warning;
			return ads_maximum_value;
		elsif (arg < -(2.00 ** msb)) then
			report "to_ads_sfixed(real) underflow, saturating"
					severity warning;
			return ads_minimum_value;
		else
			partial_result := abs(arg);
		end if;

		for i in ret'range loop
			if partial_result >= 2.0 ** i then
				ret(i) := '1';
				partial_result := partial_result - 2.0 ** i;
			else
				ret(i) := '0';
			end if;
		end loop;

		if arg < 0.0 then
			return -ret;
		end if;

		return ret;
	end function to_ads_sfixed;

	-- take an ads_sfixed and make it into a signed
	function to_signed (
			arg: in ads_sfixed
		) return signed
	is
		variable ret: signed(arg'length - 1 downto 0);
	begin
		for i in ret'range loop
			ret(i) := arg(i - lsb);
		end loop;
		return ret;
	end function to_signed;

	-- ads_sfixed + ads_sfixed
	function "+" (
			l, r:	in ads_sfixed
		) return ads_sfixed
	is
		variable extended_l: signed(l'length-1 downto 0);
		variable extended_r: signed(r'length-1 downto 0);

		variable msb_ex_l: std_logic;
		variable msb_ex_r: std_logic;
		variable msb_result: std_logic;

		variable overflow, underflow: boolean;

		variable result: signed(extended_l'range);
		variable ret: ads_sfixed;
	begin

		for i in l'range loop
			extended_l(i + lsb) := l(i);
			extended_r(i + lsb) := r(i);
		end loop;

		msb_ex_l := extended_l(extended_l'high);
		msb_ex_r := extended_r(extended_r'high);

		result := extended_l + extended_r;
		msb_result := result(result'high);

		overflow := (msb_result and (not msb_ex_l)
						and (not msb_ex_r)) = '1';

		underflow := ((not msb_result)
					and msb_ex_l and msb_ex_r) = '1';

		if overflow then
			report "saturating addition overflow" severity warning;
			result := maximum_value;
		elsif underflow then
			report "saturating addition underflow" severity warning;
			result := minimum_value;
		end if;

		for i in ret'range loop
			ret(i) := result(i + lsb);
		end loop;

		return ret;
	end function "+";

	-- ads_sfixed - ads_sfixed
	function "-" (
			l, r:	in ads_sfixed
		) return ads_sfixed
	is
		variable extended_l: signed(l'length-1 downto 0);
		variable extended_r: signed(r'length-1 downto 0);

		variable msb_ex_l: std_logic;
		variable msb_ex_r: std_logic;
		variable msb_result: std_logic;

		variable overflow, underflow: boolean;

		variable result: signed(extended_l'range);
		variable ret: ads_sfixed;
	begin

		for i in l'range loop
			extended_l(i + lsb) := l(i);
			extended_r(i + lsb) := r(i);
		end loop;

		result := extended_l - extended_r;

		msb_ex_l := extended_l(extended_l'high);
		msb_ex_r := extended_r(extended_r'high);
		msb_result := result(result'high);

		overflow := ((not msb_ex_l) and msb_ex_r
						and msb_result) = '1';
		underflow := (msb_ex_l and (not msb_ex_r)
						and (not msb_result)) = '1';

		if overflow then
			report "saturating subtraction overflow" severity warning;
			result := maximum_value;
		elsif underflow then
			report "saturating subtraction underflow" severity warning;
			result := minimum_value;
		end if;

		for i in ret'range loop
			ret(i) := result(i + lsb);
		end loop;

		return ret;
	end function "-";

	-- -ads_sfixed
	function "-" (
			r:	in ads_sfixed
		) return ads_sfixed
	is
		variable cbit: std_logic := '1';
		variable ret: ads_sfixed;
	begin
		for i in r'low to r'high loop
			ret(i) := (not r(i)) xor cbit;
			cbit := cbit and (not r(i));
		end loop;
		return ret;
	end function "-";

	-- ads_sfixed * ads_sfixed
	function "*" (
			l, r: in ads_sfixed
		) return ads_sfixed
	is
		variable extended_l, extended_r: signed(l'length-1 downto 0);
		variable extended_result: signed(2*l'length-1 downto 0);
		variable ret: ads_sfixed := (others => '0');
		variable result_msb: std_logic;
		variable l_msb, r_msb: std_logic;
		variable overflow, underflow: boolean;
		constant cutoff: natural :=2*lsb + msb;
		variable extended_result_upper: std_logic_vector(2*l'length-cutoff-1 downto 0);
	begin

		for i in l'range loop
			extended_l(i+lsb) := l(i);
			extended_r(i+lsb) := r(i);
		end loop;

		extended_result := extended_l * extended_r;


		-- overflow checks
		l_msb := extended_l(extended_l'high);
		r_msb := extended_r(extended_r'high);
		extended_result_upper := std_logic_vector(
						extended_result(extended_result'high downto cutoff));

		overflow := (((r_msb = '0') and (l_msb = '0'))
				or ((r_msb = '1') and (l_msb = '1')))
				and (unary_or(extended_result_upper) = '1');
		underflow := ((r_msb = '1') xor (l_msb = '1'))
				and ((extended_l /= 0) and (extended_r /= 0))
				and (unary_and(extended_result_upper) = '0');

		if overflow then
			report "saturating multiplication overflow" severity warning;
			return to_ads_sfixed(maximum_value);
		elsif underflow then
			report "saturating multiplication underflow" severity warning;
			return to_ads_sfixed(minimum_value);
		end if;

		for i in ret'range loop
			ret(i) := extended_result(i + 2*lsb);
		end loop;

		return ret;

	end function "*";


	-- ads_sfixed / ads_sfixed
	function "/" (
			l, r: in ads_sfixed
		) return ads_sfixed
	is
		variable ret: ads_sfixed;
		variable l_s: signed(l'length+lsb-1 downto 0);
		variable r_s: signed(l'length+lsb-1 downto 0);
		variable ret_s: signed(l'length+lsb-1 downto 0);
	begin
		l_s := (others => '0');
		r_s := (others => '0');
		for i in ret'range loop
			l_s(i+2*lsb) := l(i);
			r_s(i+lsb) := r(i);
		end loop;
		ret_s := l_s / r_s;
		for i in ret'range loop
			ret(i) := ret_s(i+lsb);
		end loop;
		return ret;
	end function "/";

	-- ads_sfixed > ads_sfixed
	function ">" (
			l, r: in ads_sfixed
		) return boolean
	is
		variable lhs: signed(l'length-1 downto 0);
		variable rhs: signed(r'length-1 downto 0);	
	begin
		for i in l'range loop
			lhs(i+lsb) := l(i);
			rhs(i+lsb) := r(i);
		end loop;

		return lhs > rhs;
	end function ">";

end package body ads_fixed;
