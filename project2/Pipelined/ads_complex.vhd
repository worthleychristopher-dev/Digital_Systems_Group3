---- this file is part of the ADS library

use work.ads_fixed.all;

package ads_complex_pkg is
	-- complex number in rectangular form
	type ads_complex is
	record
		re: ads_sfixed;
		im: ads_sfixed;
	end record ads_complex;

	---- functions

	-- make a complex number
	function ads_cmplx (re, im: in ads_sfixed) return ads_complex;

	-- returns l + r
	function "+" (l, r: in ads_complex) return ads_complex;

	-- returns l - r
	function "-" (l, r: in ads_complex) return ads_complex;

	-- returns l * r
	function "*" (l, r: in ads_complex) return ads_complex;

	-- returns the complex conjugate of arg
	function conj (arg: in ads_complex) return ads_complex;

	-- returns || arg || ** 2
	function abs2 (arg: in ads_complex) return ads_sfixed;

	-- constants
	constant complex_zero: ads_complex :=
					ads_cmplx(to_ads_sfixed(0), to_ads_sfixed(0));

end package ads_complex_pkg;

package body ads_complex_pkg is

	function ads_cmplx (re, im: in ads_sfixed) return ads_complex is
	begin
		return (re => re, im => im);
	end function ads_cmplx;

	function "+" (l, r: in ads_complex) return ads_complex is
	begin
		return (
		  re => l.re + r.re,
		  im => l.im + r.im
		);
	end function "+";

	function "-" (l, r: in ads_complex) return ads_complex is
	begin
		return (
		  re => l.re - r.re,
		  im => l.im - r.im
		);
	end function "-";

	function "*" (l, r: in ads_complex) return ads_complex is
	begin
		return (
		  re => (l.re * r.re) - (l.im * r.im),
		  im => (l.re * r.im) + (l.im * r.re)
		);
	end function "*";

	function conj (arg: in ads_complex) return ads_complex is
	begin
		return (re => arg.re, im => -arg.im);
	end function conj;
	
	
	function abs2 (arg: in ads_complex) return ads_sfixed is
	begin
		return arg.re * arg.re + arg.im * arg.im;
	end function abs2;

end package body ads_complex_pkg;
