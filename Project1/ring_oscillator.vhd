-- ring_oscillator.vhd 
-- Parametric ring oscillator: 1 control NAND + (n-1) inverters
-- Synthesis must fail if n is even.

library ieee;
use ieee.std_logic_1164.all;

entity ring_oscillator is
  generic (
    n : positive := 13  -- total stages including NAND stage(0); must be odd
  );
  port (
    enable : in  std_logic;
    ro_out : out std_logic
  );
end entity;

architecture rtl of ring_oscillator is
  signal stage : std_logic_vector(n-1 downto 0);

  -- Plain VHDL attributes (Quartus supports these)
  attribute keep     : boolean;
  attribute preserve : boolean;
  attribute keep of stage : signal is true;
  attribute preserve of stage : signal is true;

begin
  -- Synthesis-time check: n must be odd
  assert (n mod 2 = 1)
    report "ring_oscillator: generic n must be odd (n mod 2 = 1)."
    severity failure;

  -- Control NAND gate:
  -- stage(0) = NOT( enable AND stage(n-1) )
  stage(0) <= not (enable and stage(n-1));

  -- Inverter chain
  gen_inv : for i in 0 to n-2 generate
    stage(i+1) <= not stage(i);
  end generate;

  ro_out <= stage(n-1);
end architecture;