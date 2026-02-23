-- ro_puf.vhd 
-- Bank of ring oscillators + counters, challenge selects two counters (one from each half)
-- Output '1' if counter(first_group) < counter(second_group) else '0'

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ro_puf is
  generic (
    ro_length     : positive := 13;  -- RO chain length (must be odd per ring_oscillator)
    ro_count      : positive := 16;  -- number of RO chains (must be power of two, >= 2)
    counter_width : positive := 16
  );
  port (
    reset     : in  std_logic;       -- async active-low reset for counters
    enable    : in  std_logic;       -- active-high enable for counters
    challenge : in  std_logic_vector;-- constrained in architecture
    response  : out std_logic
  );
end entity;

architecture rtl of ro_puf is

  -- ========= FUNCTIONS =========

  function clog2(x : positive) return natural is
    variable v : natural := x - 1;
    variable r : natural := 0;
  begin
    while v > 0 loop
      v := v / 2;
      r := r + 1;
    end loop;
    return r;
  end function;

  function is_power_of_two(x : positive) return boolean is
    variable v : natural := x;
  begin
    while (v mod 2 = 0) loop
      v := v / 2;
    end loop;
    return (v = 1);
  end function;

  -- ========= CONSTANTS =========

  constant b          : natural := clog2(ro_count);
  constant group_size : natural := ro_count / 2;
  constant chall_w    : natural := 2 * (b - 1);

  -- ========= TYPES / SIGNALS =========

  subtype counter_t is unsigned(counter_width-1 downto 0);
  type counter_arr_t is array (0 to ro_count-1) of counter_t;

  signal ro_sig   : std_logic_vector(0 to ro_count-1);
  signal counters : counter_arr_t := (others => (others => '0'));

  signal idx_a : natural range 0 to group_size-1 := 0;
  signal idx_b : natural range 0 to group_size-1 := 0;

begin

  -- ========= ASSERTIONS / CHECKS =========

  assert (ro_count >= 2)
    report "ro_puf: ro_count must be >= 2."
    severity failure;

  assert is_power_of_two(ro_count)
    report "ro_puf: ro_count must be a power of two."
    severity failure;

  assert (challenge'length = chall_w)
    report "ro_puf: challenge width must be 2*(b-1) where b=log2(ro_count)."
    severity failure;

  -- ========= RING OSCILLATORS =========
  gen_ros : for i in 0 to ro_count-1 generate
    ro_i : entity work.ring_oscillator
      generic map ( n => ro_length )
      port map (
        enable => enable,
        ro_out => ro_sig(i)
      );
  end generate;

  -- ========= COUNTERS =========
  gen_cnt : for i in 0 to ro_count-1 generate
    process(ro_sig(i), reset)
    begin
      if reset = '0' then
        counters(i) <= (others => '0');
      elsif rising_edge(ro_sig(i)) then
        if enable = '1' then
          counters(i) <= counters(i) + 1;
        end if;
      end if;
    end process;
  end generate;

  -- ========= CHALLENGE DECODE =========
  -- VHDL-93: explicit sensitivity list instead of process(all)
  decode_p : process(challenge)
    variable lo : natural;
    variable hi : natural;
  begin
    lo := to_integer(unsigned(challenge((b-1)-1 downto 0)));
    hi := to_integer(unsigned(challenge(chall_w-1 downto (b-1))));

    idx_a <= lo;
    idx_b <= hi;
  end process;

  -- ========= COMPARISON =========
  -- Sensitivity list includes anything used on RHS (for combinational behavior)
  compare_p : process(counters, idx_a, idx_b)
    variable a_val : counter_t;
    variable b_val : counter_t;
  begin
    a_val := counters(idx_a);
    b_val := counters(group_size + idx_b);

    if a_val < b_val then
      response <= '1';
    else
      response <= '0';
    end if;
  end process;

end architecture;